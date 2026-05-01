//! Ephemeral help-request chat handlers.
//!
//! State machine: RAISED → ACTIVE (first join) → CLOSED (creator/participant close)
//! On CLOSE: broadcast `ephemeral_deleted` to all participants, then DELETE the session row.
//! All state transitions are idempotent — duplicate CLOSE is a no-op.

use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use axum::extract::ws::Message;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;
use crate::relay::ws_handler::ConnectionMap;

// ---------------------------------------------------------------------------
// DB row types
// ---------------------------------------------------------------------------

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct EphemeralSession {
    pub id: Uuid,
    pub creator_id: String,
    pub group_id: String,
    pub state: String,
    pub created_at: DateTime<Utc>,
    pub closed_at: Option<DateTime<Utc>>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, sqlx::FromRow)]
struct ParticipantRow {
    user_id: String,
}

#[derive(Debug, sqlx::FromRow)]
struct GroupIdRow {
    group_id: Option<Uuid>,
}

#[derive(Debug, sqlx::FromRow)]
struct MemberIdRow {
    id: Uuid,
}

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct RaiseRequest {
    // Optional label for the session, reserved for future use.
    #[serde(default)]
    #[allow(dead_code)]
    pub label: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct SessionResponse {
    pub session: EphemeralSession,
}

#[derive(Debug, Serialize)]
pub struct ActiveSessionsResponse {
    pub sessions: Vec<EphemeralSession>,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Fetch the group_id UUID for a user.
async fn get_user_group(pool: &DbPool, user_id: Uuid) -> Result<Uuid, AppError> {
    let row = sqlx::query_as::<_, GroupIdRow>("SELECT group_id FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(AppError::Database)?;

    match row {
        Some(GroupIdRow { group_id: Some(gid) }) => Ok(gid),
        Some(GroupIdRow { group_id: None }) => {
            Err(AppError::BadRequest("user is not in a group".to_string()))
        }
        None => Err(AppError::NotFound("user not found".to_string())),
    }
}

/// Broadcast a JSON message to a list of user IDs (by UUID) that are currently online.
async fn broadcast_to_users(connections: &ConnectionMap, user_ids: &[Uuid], payload: &str) {
    let senders: Vec<_> = {
        let guard = connections.read().await;
        user_ids
            .iter()
            .filter_map(|uid| guard.get(uid).cloned().map(|tx| (*uid, tx)))
            .collect()
    };
    for (uid, tx) in senders {
        if tx.try_send(Message::Text(payload.to_string())).is_err() {
            tracing::warn!(user_id = %uid, "ephemeral broadcast: channel full, message dropped");
        }
    }
}

/// Fetch all member UUIDs for a group.
async fn get_group_members(pool: &DbPool, group_id: Uuid) -> Result<Vec<Uuid>, AppError> {
    let rows =
        sqlx::query_as::<_, MemberIdRow>("SELECT id FROM users WHERE group_id = $1")
            .bind(group_id)
            .fetch_all(pool)
            .await
            .map_err(AppError::Database)?;
    Ok(rows.into_iter().map(|r| r.id).collect())
}

/// Fetch all participant user_ids for a session and parse them as UUIDs (best-effort).
async fn get_session_participants(
    pool: &DbPool,
    session_id: Uuid,
) -> Result<Vec<Uuid>, AppError> {
    let rows = sqlx::query_as::<_, ParticipantRow>(
        "SELECT user_id FROM ephemeral_participants WHERE session_id = $1",
    )
    .bind(session_id)
    .fetch_all(pool)
    .await
    .map_err(AppError::Database)?;

    let ids: Vec<Uuid> = rows
        .iter()
        .filter_map(|r| r.user_id.parse::<Uuid>().ok())
        .collect();
    Ok(ids)
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// POST /ephemeral/raise
///
/// Creates a new help-request session (state=RAISED) in the caller's group and
/// broadcasts `{type:"ephemeral_raised", sessionId, creatorId}` to every online
/// group member.
pub async fn raise_flag(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Json(_body): Json<RaiseRequest>,
) -> Result<impl IntoResponse, AppError> {
    let group_id = get_user_group(&pool, auth.user_id).await?;
    let creator_id = auth.user_id.to_string();
    let group_id_str = group_id.to_string();

    let session = sqlx::query_as::<_, EphemeralSession>(
        "INSERT INTO ephemeral_sessions (creator_id, group_id, state)
         VALUES ($1, $2, 'RAISED')
         RETURNING id, creator_id, group_id, state, created_at, closed_at, expires_at",
    )
    .bind(&creator_id)
    .bind(&group_id_str)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    // Broadcast to all online group members.
    let member_ids = get_group_members(&pool, group_id).await?;
    let notification = json!({
        "type": "ephemeral_raised",
        "sessionId": session.id,
        "creatorId": creator_id,
    })
    .to_string();
    broadcast_to_users(&connections, &member_ids, &notification).await;

    Ok((StatusCode::CREATED, Json(SessionResponse { session })))
}

/// POST /ephemeral/:id/join
///
/// Adds the caller as a participant. Transitions state RAISED→ACTIVE on first join.
/// Broadcasts `{type:"ephemeral_joined", sessionId, userId}` to all current participants.
pub async fn join_session(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Path(session_id): Path<Uuid>,
) -> Result<impl IntoResponse, AppError> {
    let group_id = get_user_group(&pool, auth.user_id).await?;
    let user_id_str = auth.user_id.to_string();

    // Fetch session and verify group membership.
    let session = sqlx::query_as::<_, EphemeralSession>(
        "SELECT id, creator_id, group_id, state, created_at, closed_at, expires_at
         FROM ephemeral_sessions WHERE id = $1",
    )
    .bind(session_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?
    .ok_or_else(|| AppError::NotFound("ephemeral session not found".to_string()))?;

    if session.group_id != group_id.to_string() {
        return Err(AppError::Forbidden("session belongs to a different group".to_string()));
    }

    // Insert participant — idempotent.
    sqlx::query(
        "INSERT INTO ephemeral_participants (session_id, user_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING",
    )
    .bind(session_id)
    .bind(&user_id_str)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    // Transition RAISED → ACTIVE on first join.
    sqlx::query(
        "UPDATE ephemeral_sessions
         SET state = 'ACTIVE'
         WHERE id = $1 AND state = 'RAISED'",
    )
    .bind(session_id)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    // Re-fetch updated session.
    let session = sqlx::query_as::<_, EphemeralSession>(
        "SELECT id, creator_id, group_id, state, created_at, closed_at, expires_at
         FROM ephemeral_sessions WHERE id = $1",
    )
    .bind(session_id)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    // Broadcast to all current participants.
    let participant_ids = get_session_participants(&pool, session_id).await?;
    let notification = json!({
        "type": "ephemeral_joined",
        "sessionId": session_id,
        "userId": user_id_str,
    })
    .to_string();
    broadcast_to_users(&connections, &participant_ids, &notification).await;

    Ok((StatusCode::OK, Json(SessionResponse { session })))
}

/// POST /ephemeral/:id/close
///
/// Closes the session. Idempotent — if the session is already CLOSED or does not
/// exist, returns 200. Persists state=CLOSED to the DB first (so the transition
/// survives a crash), then broadcasts `{type:"ephemeral_deleted", sessionId}` to
/// all current participants.
pub async fn close_session(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Path(session_id): Path<Uuid>,
) -> Result<impl IntoResponse, AppError> {
    let _ = auth.user_id;

    // Idempotent check: if the session doesn't exist or is already CLOSED, return 200.
    let state_row: Option<String> = sqlx::query_scalar(
        "SELECT state FROM ephemeral_sessions WHERE id = $1",
    )
    .bind(session_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    match state_row.as_deref() {
        None | Some("CLOSED") => {
            return Ok((StatusCode::OK, Json(json!({ "closed": true, "idempotent": true }))));
        }
        _ => {}
    }

    // Fetch participants while the session is still RAISED/ACTIVE.
    let participant_ids = get_session_participants(&pool, session_id).await?;

    // Persist CLOSED state before broadcasting so the transition is durable.
    sqlx::query(
        "UPDATE ephemeral_sessions
         SET state = 'CLOSED', closed_at = NOW()
         WHERE id = $1 AND state != 'CLOSED'",
    )
    .bind(session_id)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    // Broadcast deletion event to all participants that were online.
    let notification = json!({
        "type": "ephemeral_deleted",
        "sessionId": session_id,
    })
    .to_string();
    broadcast_to_users(&connections, &participant_ids, &notification).await;

    Ok((StatusCode::OK, Json(json!({ "closed": true }))))
}

/// GET /ephemeral/active
///
/// Returns all RAISED or ACTIVE sessions in the caller's group.
pub async fn list_active(
    State(pool): State<DbPool>,
    auth: AuthUser,
) -> Result<impl IntoResponse, AppError> {
    let group_id = get_user_group(&pool, auth.user_id).await?;

    let sessions = sqlx::query_as::<_, EphemeralSession>(
        "SELECT id, creator_id, group_id, state, created_at, closed_at, expires_at
         FROM ephemeral_sessions
         WHERE group_id = $1
           AND state IN ('RAISED', 'ACTIVE')
           AND expires_at > NOW()
         ORDER BY created_at ASC",
    )
    .bind(group_id.to_string())
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    Ok(Json(ActiveSessionsResponse { sessions }))
}
