//! Wire types for the WebSocket message relay.
//!
//! The server treats `payload` as an opaque blob — it is NEVER decoded or
//! inspected. End-to-end encryption happens entirely on the client.

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Presence status for a connected user.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PresenceStatus {
    Online,
    Away,
    Offline,
}

/// Inbound message variants sent from a client to the server.
///
/// Wire format uses a `"type"` discriminant field:
/// - `{ "type": "auth",     "token": "<session_token>" }`  ← **must be the first message**
/// - `{ "type": "send",     "to": "<uuid>",     "payload": "<base64>" }`
/// - `{ "type": "ping" }`
/// - `{ "type": "presence", "status": "online"|"away"|"offline" }`
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    /// Authentication handshake — must be first message; connection is closed with
    /// code 4001 if not received within 10 seconds or if the token is invalid.
    Auth { token: String },
    /// Send an encrypted envelope to a user or group UUID. Server never reads `payload`.
    Send { to: Uuid, payload: String },
    /// Heartbeat / keep-alive — server replies with pong.
    Ping,
    /// Explicit presence status update.
    Presence { status: PresenceStatus },
}

/// Outbound message variants sent from the server to a client.
///
/// Wire format uses a `"type"` discriminant field:
/// - `{ "type": "envelope",        "from": "<uuid>", "payload": "<base64>" }`
/// - `{ "type": "presence_update", "user_id": "<uuid>", "status": "online"|"away"|"offline" }`
/// - `{ "type": "error",           "message": "<string>" }`
/// - `{ "type": "pong" }`
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    /// Forwarded message envelope — `payload` is opaque, server never inspects it.
    Envelope { from: Uuid, payload: String },
    /// Presence update for a group member.
    PresenceUpdate { user_id: Uuid, status: PresenceStatus },
    /// Error notice (routing failure, auth error, etc.).
    Error { message: String },
    /// Reply to a client Ping.
    Pong,
}
