// POST /messages/:id/ack
// Called by client after it has persisted a message locally
// Marks the message as acknowledged — server deletes it shortly after
// This is how the "sealed envelope" model works:
//   1. Message arrives, stored in server offline queue
//   2. Recipient connects, server delivers all queued messages
//   3. Client receives, persists to local drift DB, calls /messages/:id/ack
//   4. Server marks acknowledged_at = NOW()
//   5. Cleanup task deletes acknowledged messages

use axum::{extract::{Path, State}, Json};
use uuid::Uuid;
use serde_json::{json, Value};
use chrono::{DateTime, Utc};
use sqlx::FromRow;

use crate::auth::middleware::AuthUser;
use crate::error::AppError;
use crate::db::DbPool;

pub async fn ack_message(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Path(message_id): Path<Uuid>,
) -> Result<Json<Value>, AppError> {
    // Only the recipient can ACK their own messages
    let result = sqlx::query(
        "UPDATE messages SET acknowledged_at = NOW() 
         WHERE id = $1 AND recipient_id = $2 AND acknowledged_at IS NULL",
    )
    .bind(message_id)
    .bind(auth.user_id)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Message not found or already acknowledged".into()));
    }

    Ok(Json(json!({"acknowledged": true, "id": message_id})))
}

#[derive(FromRow)]
struct PendingMessage {
    id: Uuid,
    sender_id: Uuid,
    payload: Vec<u8>,
    created_at: DateTime<Utc>,
}

// Also expose: GET /messages/pending
// Returns all unacknowledged messages for the authenticated user
// Called on reconnect to drain the offline queue
pub async fn get_pending_messages(
    State(pool): State<DbPool>,
    auth: AuthUser,
) -> Result<Json<Value>, AppError> {
    let messages = sqlx::query_as::<_, PendingMessage>(
        r#"SELECT id, sender_id, payload, created_at 
           FROM messages 
           WHERE recipient_id = $1 AND acknowledged_at IS NULL
           ORDER BY created_at ASC
           LIMIT 500"#,
    )
    .bind(auth.user_id)
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    let result: Vec<_> = messages.iter().map(|m| json!({
        "id": m.id,
        "from": m.sender_id,
        "payload": base64::Engine::encode(&base64::engine::general_purpose::STANDARD, &m.payload),
        "created_at": m.created_at,
    })).collect();

    Ok(Json(json!({"messages": result})))
}
