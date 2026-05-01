//! WebSocket upgrade handler — authenticated dumb-pipe message relay.
//!
//! Auth:     The client connects to `GET /ws` with no token in the URL.
//!           The first message must be `{"type":"auth","token":"<session_token>"}`.
//!           The server waits up to 10 seconds; on timeout or invalid token it sends
//!           WS close code 4001.
//! Routing:  Enforces group membership — users may only message peers that share
//!           their group_id. Server NEVER inspects `payload` bytes.
//! Presence: Broadcasts online/offline to all group members on connect/disconnect.
//! Offline:  Messages to offline users are queued in memory and drained on reconnect.

use std::{
    borrow::Cow,
    collections::HashMap,
    sync::Arc,
    time::Duration,
};

use axum::{
    extract::{
        ws::{CloseFrame, Message, WebSocket, WebSocketUpgrade},
        FromRef, State,
    },
    response::{IntoResponse, Response},
};
use futures_util::{SinkExt, StreamExt};
use tokio::sync::{mpsc, RwLock};
use tracing::instrument;
use uuid::Uuid;

use super::message_types::{ClientMessage, PresenceStatus, ServerMessage};
use crate::{auth::challenge::SessionStore, db::DbPool, push::sender::PushSender};

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Sender half for a connected peer (bounded channel, capacity 256).
pub type PeerTx = mpsc::Sender<Message>;

// BLOCKED(phase-2): ConnectionMap is node-local — replace with Redis pub/sub for
// multi-node deployments so messages can be routed across instances.
/// Shared map of connected peers: user_id → sender channel.
pub type ConnectionMap = Arc<RwLock<HashMap<Uuid, PeerTx>>>;

// BLOCKED(phase-2): OfflineQueue is in-memory and lost on server restart — replace
// with DB-backed persistence (e.g. a `queued_messages` table) in Phase 2.
/// Per-user offline message queue: user_id → JSON-serialised `ServerMessage` strings.
///
/// Messages are drained to the client on reconnect.
pub type OfflineQueue = Arc<RwLock<HashMap<Uuid, Vec<String>>>>;

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

/// Axum handler: upgrades the connection to a WebSocket.
///
/// Authentication is deferred to the first WebSocket message
/// (`{"type":"auth","token":"<session_token>"}`) rather than the URL, so
/// session tokens never appear in proxy or access logs.
pub async fn ws_handler<S>(
    ws: WebSocketUpgrade,
    State(state): State<S>,
) -> Response
where
    S: Clone + Send + Sync + 'static,
    SessionStore: FromRef<S>,
    ConnectionMap: FromRef<S>,
    OfflineQueue: FromRef<S>,
    DbPool: FromRef<S>,
    PushSender: FromRef<S>,
{
    let sessions = SessionStore::from_ref(&state);
    let connections = ConnectionMap::from_ref(&state);
    let offline_queue = OfflineQueue::from_ref(&state);
    let db = DbPool::from_ref(&state);
    let push_sender = PushSender::from_ref(&state);

    ws.on_upgrade(move |socket| handle_socket(socket, sessions, connections, offline_queue, db, push_sender))
        .into_response()
}

// ---------------------------------------------------------------------------
// Socket driver
// ---------------------------------------------------------------------------

#[instrument(skip(socket, sessions, connections, offline_queue, db, push_sender))]
async fn handle_socket(
    socket: WebSocket,
    sessions: SessionStore,
    connections: ConnectionMap,
    offline_queue: OfflineQueue,
    db: DbPool,
    push_sender: PushSender,
) {
    let (mut sink, mut stream) = socket.split();

    // --- Auth handshake: wait up to 10 s for {"type":"auth","token":"..."} ---
    let user_id = match tokio::time::timeout(Duration::from_secs(10), stream.next()).await {
        Err(_) => {
            tracing::warn!("auth timeout — closing connection");
            let _ = sink
                .send(Message::Close(Some(CloseFrame {
                    code: 4001,
                    reason: Cow::Borrowed("auth timeout"),
                })))
                .await;
            return;
        }
        Ok(None) => {
            tracing::warn!("connection closed before auth");
            return;
        }
        Ok(Some(Err(e))) => {
            tracing::warn!("WS error during auth handshake: {e}");
            return;
        }
        Ok(Some(Ok(Message::Text(text)))) => {
            match serde_json::from_str::<ClientMessage>(&text) {
                Ok(ClientMessage::Auth { token }) => {
                    // Scope the lock so the MutexGuard is dropped before any await.
                    let lookup = {
                        let map = sessions.0.lock().expect("session store poisoned");
                        map.get(&token).map(|e| e.user_id)
                    };
                    match lookup {
                        Some(id) => id,
                        None => {
                            tracing::warn!("invalid session token during WS auth");
                            let _ = sink
                                .send(Message::Close(Some(CloseFrame {
                                    code: 4001,
                                    reason: Cow::Borrowed("invalid or expired session token"),
                                })))
                                .await;
                            return;
                        }
                    }
                }
                _ => {
                    tracing::warn!("first WS message was not an auth frame");
                    let _ = sink
                        .send(Message::Close(Some(CloseFrame {
                            code: 4001,
                            reason: Cow::Borrowed("first message must be auth"),
                        })))
                        .await;
                    return;
                }
            }
        }
        Ok(Some(Ok(_))) => {
            tracing::warn!("first WS message was not a text frame");
            let _ = sink
                .send(Message::Close(Some(CloseFrame {
                    code: 4001,
                    reason: Cow::Borrowed("first message must be text auth"),
                })))
                .await;
            return;
        }
    };

    tracing::info!(user_id = %user_id, "peer authenticated");

    // Cache the sender's group_id at connect time — never queried per message.
    // BLOCKED(allowlist): users without groups shouldn't connect
    let sender_group_id = match fetch_user_group(&db, user_id).await {
        Ok(Some(Some(gid))) => gid,
        Ok(Some(None)) => {
            tracing::warn!(user_id = %user_id, "user has no group assigned — closing");
            let _ = sink
                .send(Message::Close(Some(CloseFrame {
                    code: 4001,
                    reason: Cow::Borrowed("user has no group assigned"),
                })))
                .await;
            return;
        }
        Ok(None) => {
            tracing::warn!(user_id = %user_id, "user not found after auth");
            return;
        }
        Err(e) => {
            tracing::error!("DB error fetching group for {user_id}: {e}");
            return;
        }
    };

    let (tx, mut rx) = mpsc::channel::<Message>(256);

    // Register this peer.
    connections.write().await.insert(user_id, tx.clone());
    tracing::info!(user_id = %user_id, "peer connected");

    // Drain any offline-queued messages for this user before announcing presence,
    // so the client receives missed messages before seeing presence updates.
    let queued = offline_queue
        .write()
        .await
        .remove(&user_id)
        .unwrap_or_default();
    for json in queued {
        if tx.try_send(Message::Text(json)).is_err() {
            tracing::warn!(user_id = %user_id, "offline queue drain: channel full, message dropped");
        }
    }

    // Announce online presence to all group peers.
    broadcast_presence(user_id, PresenceStatus::Online, &db, &connections).await;

    // Spawn a task that drains the outbound channel into the WebSocket sink.
    let send_task = tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if sink.send(msg).await.is_err() {
                break;
            }
        }
    });

    // Read loop — handle inbound frames.
    while let Some(Ok(raw)) = stream.next().await {
        match raw {
            Message::Text(text) => {
                handle_text_message(&text, user_id, sender_group_id, &tx, &connections, &offline_queue, &db, &push_sender).await;
            }
            Message::Binary(bytes) => {
                tracing::warn!(len = bytes.len(), "ignoring unexpected binary frame");
            }
            Message::Close(_) => break,
            _ => {}
        }
    }

    // Deregister on disconnect.
    connections.write().await.remove(&user_id);
    tracing::info!(user_id = %user_id, "peer disconnected");

    // Announce offline presence to group peers.
    broadcast_presence(user_id, PresenceStatus::Offline, &db, &connections).await;

    send_task.abort();
}

// ---------------------------------------------------------------------------
// Message dispatch
// ---------------------------------------------------------------------------

async fn handle_text_message(
    text: &str,
    from: Uuid,
    sender_group_id: Uuid,
    self_tx: &PeerTx,
    connections: &ConnectionMap,
    offline_queue: &OfflineQueue,
    db: &DbPool,
    push_sender: &PushSender,
) {
    let client_msg: ClientMessage = match serde_json::from_str(text) {
        Ok(m) => m,
        Err(e) => {
            send_error(self_tx, &format!("invalid message: {e}"));
            return;
        }
    };

    match client_msg {
        ClientMessage::Auth { .. } => {
            // Auth is only valid as the very first message; reject duplicates.
            send_error(self_tx, "already authenticated");
        }
        ClientMessage::Send { to, payload } => {
            handle_send(from, sender_group_id, to, payload, db, connections, offline_queue, self_tx, push_sender).await;
        }
        ClientMessage::Ping => {
            let _ = self_tx.try_send(Message::Text(
                serde_json::to_string(&ServerMessage::Pong).unwrap_or_default(),
            ));
        }
        ClientMessage::Presence { status } => {
            broadcast_presence(from, status, db, connections).await;
        }
    }
}

/// Route a `Send` message from `sender_id` to `to` (a user or group UUID).
///
/// Group membership is enforced: sender and recipient must share a `group_id`.
/// The `payload` bytes are forwarded verbatim — the server never inspects them.
async fn handle_send(
    sender_id: Uuid,
    sender_group_id: Uuid,  // pre-fetched at connect, not queried per message
    to: Uuid,
    payload: String,
    db: &DbPool,
    connections: &ConnectionMap,
    offline_queue: &OfflineQueue,
    self_tx: &PeerTx,
    push_sender: &PushSender,
) {
    match fetch_user_group(db, to).await {
        Err(e) => {
            tracing::error!("DB error resolving recipient {to}: {e}");
            send_error(self_tx, "internal error");
        }

        // Case A — `to` is a user.
        Ok(Some(recipient_group_opt)) => {
            if recipient_group_opt != Some(sender_group_id) {
                send_error(self_tx, "recipient is not in your group");
                return;
            }
            let envelope = ServerMessage::Envelope { from: sender_id, payload };
            let json = serde_json::to_string(&envelope).unwrap_or_default();
            // Collect the sender before dropping the lock; never hold RwLock across await.
            let peer_tx = connections.read().await.get(&to).cloned();
            if let Some(peer_tx) = peer_tx {
                if let Err(e) = peer_tx.try_send(Message::Text(json)) {
                    tracing::warn!(recipient = %to, "send: channel full, message dropped: {e}");
                }
            } else {
                // Recipient is offline — queue for delivery on reconnect.
                offline_queue
                    .write()
                    .await
                    .entry(to)
                    .or_default()
                    .push(json);

                // Fire a silent wake-only push (no content — just wakes the app).
                // Push failure is non-fatal: message is already in the offline queue.
                send_silent_push_for_user(db, push_sender, to).await;
            }
        }

        // Case B — `to` is not a user; treat it as a group UUID.
        Ok(None) => {
            if to != sender_group_id {
                send_error(self_tx, "you are not a member of this group");
                return;
            }
            let members = match fetch_group_member_ids(db, to).await {
                Ok(m) => m,
                Err(e) => {
                    tracing::error!("DB error fetching members of group {to}: {e}");
                    send_error(self_tx, "internal error");
                    return;
                }
            };
            let envelope = ServerMessage::Envelope { from: sender_id, payload };
            let json = serde_json::to_string(&envelope).unwrap_or_default();
            // Determine which group members are online before sending.
            let online_ids: Vec<Uuid> = {
                let guard = connections.read().await;
                members
                    .iter()
                    .filter(|&&mid| mid != sender_id)
                    .filter(|mid| guard.contains_key(*mid))
                    .copied()
                    .collect()
            };
            // Collect senders while holding read lock, then drop lock before sending.
            let senders: Vec<(Uuid, PeerTx)> = {
                let guard = connections.read().await;
                members
                    .iter()
                    .filter(|&&mid| mid != sender_id)
                    .filter_map(|mid| guard.get(mid).map(|tx| (*mid, tx.clone())))
                    .collect()
            };
            for (mid, peer_tx) in senders {
                if let Err(e) = peer_tx.try_send(Message::Text(json.clone())) {
                    tracing::warn!(recipient = %mid, "group send: channel full, message dropped: {e}");
                }
                // Offline group-message recipients are not queued (direct messages only).
            }
            // Notify offline group members with a silent push.
            for mid in members.iter().filter(|&&mid| mid != sender_id && !online_ids.contains(&mid)) {
                send_silent_push_for_user(db, push_sender, *mid).await;
            }
        }
    }
}

/// Look up device tokens for `user_id` and fire a silent wake push.
/// Returns immediately; actual sending is spawned in the background.
async fn send_silent_push_for_user(db: &DbPool, push_sender: &PushSender, user_id: Uuid) {
    #[derive(sqlx::FromRow)]
    struct TokenRow {
        platform: String,
        token: String,
    }

    let tokens: Vec<TokenRow> = match sqlx::query_as(
        r#"SELECT dt.platform, dt.token
           FROM device_tokens dt
           JOIN users u ON encode(decode(u.public_key, 'base64'), 'hex') = dt.public_key_hex
           WHERE u.id = $1"#,
    )
    .bind(user_id)
    .fetch_all(db)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            tracing::warn!(user_id = %user_id, "push: DB error looking up device tokens: {e}");
            return;
        }
    };

    for row in tokens {
        crate::push::sender::fire_and_forget(push_sender.clone(), row.token, row.platform);
    }
}

// ---------------------------------------------------------------------------
// Presence helpers
// ---------------------------------------------------------------------------

// BLOCKED(phase-3): presence broadcast queries all group members from DB on every connect/disconnect
//   Cache group member list in memory after Phase 3 MLS implementation when membership is stable
/// Broadcast a presence update for `user_id` to all currently-online group peers.
async fn broadcast_presence(
    user_id: Uuid,
    status: PresenceStatus,
    db: &DbPool,
    connections: &ConnectionMap,
) {
    let group_id = match fetch_user_group(db, user_id).await {
        Ok(Some(Some(gid))) => gid,
        _ => return, // no group or DB error — nothing to broadcast
    };

    let members = match fetch_group_member_ids(db, group_id).await {
        Ok(m) => m,
        Err(e) => {
            tracing::error!("DB error fetching group members for presence broadcast: {e}");
            return;
        }
    };

    let msg = ServerMessage::PresenceUpdate { user_id, status };
    let json = serde_json::to_string(&msg).unwrap_or_default();
    // Collect senders while holding read lock, then drop lock before sending.
    let senders: Vec<PeerTx> = {
        let guard = connections.read().await;
        members.iter().filter_map(|mid| guard.get(mid).cloned()).collect()
    };
    for tx in senders {
        if let Err(e) = tx.try_send(Message::Text(json.clone())) {
            tracing::warn!("presence broadcast: channel full, message dropped: {e}");
        }
    }
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

fn send_error(tx: &PeerTx, message: &str) {
    let err = ServerMessage::Error { message: message.to_string() };
    let _ = tx.try_send(Message::Text(
        serde_json::to_string(&err).unwrap_or_default(),
    ));
}

// ---------------------------------------------------------------------------
// DB helpers
// ---------------------------------------------------------------------------

/// Fetch a user's `group_id`.
///
/// Returns:
/// - `Ok(Some(Some(uuid)))` — user found, belongs to a group.
/// - `Ok(Some(None))`       — user found, no group assigned.
/// - `Ok(None)`             — no user with that id.
/// - `Err(_)`               — database error.
async fn fetch_user_group(
    db: &DbPool,
    user_id: Uuid,
) -> Result<Option<Option<Uuid>>, sqlx::Error> {
    #[derive(sqlx::FromRow)]
    struct Row {
        group_id: Option<Uuid>,
    }

    let row = sqlx::query_as::<_, Row>("SELECT group_id FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(db)
        .await?;

    Ok(row.map(|r| r.group_id))
}

/// Fetch all user IDs that belong to the given group.
async fn fetch_group_member_ids(
    db: &DbPool,
    group_id: Uuid,
) -> Result<Vec<Uuid>, sqlx::Error> {
    sqlx::query_scalar::<_, Uuid>("SELECT id FROM users WHERE group_id = $1")
        .bind(group_id)
        .fetch_all(db)
        .await
}
