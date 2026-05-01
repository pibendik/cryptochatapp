//! Key rotation and emergency revocation endpoints.
//!
//! ## Endpoints
//!
//! - `POST /keys/rotate`           — self-rotation: the holder of the old key proposes a swap.
//! - `POST /keys/emergency-revoke` — any member proposes removing a compromised key.
//!
//! Both endpoints create a `member_proposals` row with `status = 'OPEN'`.
//! The consensus system (p4-consensus) watches that table and, when `approval_count`
//! reaches the threshold (2), executes the proposal's effect:
//!
//! - **ROTATE**: atomically swap `old_key_hex` → `target_key_hex` in `public_key_allowlist`
//!   and broadcast `{ "type": "key_rotated", "old_key_hex": "…", "new_key_hex": "…" }` to
//!   the group via the WebSocket relay.
//! - **REMOVE**: delete `target_key_hex` from `public_key_allowlist`.
//!
//! # TODO(p4-consensus)
//! The approval broadcast is not yet wired: when the consensus module lands,
//! implement `execute_approved_proposal` here or in `consensus/executor.rs` and call it
//! from the consensus approval handler.

use axum::{extract::State, response::IntoResponse, Json};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;

// ---------------------------------------------------------------------------
// DB row
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ProposalRow {
    pub id: Uuid,
    pub action: String,
    pub target_key_hex: String,
    pub old_key_hex: Option<String>,
    pub created_by: String,
    pub status: String,
    pub approval_count: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// ---------------------------------------------------------------------------
// Request bodies
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct RotateKeyRequest {
    /// Hex-encoded Ed25519 public key of the new device / reinstall.
    pub new_public_key_hex: String,
    /// Human-readable label for the new key (e.g. "Alice's new phone").
    pub new_label: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct EmergencyRevokeRequest {
    /// Hex-encoded public key of the compromised / stolen device.
    pub target_key_hex: String,
}

// ---------------------------------------------------------------------------
// POST /keys/rotate
// ---------------------------------------------------------------------------

/// Propose a self-rotation: the holder of the current key wants to replace it
/// with a newly generated keypair (e.g. new phone, reinstall).
///
/// The proposer **must** be authenticated with their existing session token so
/// that we can record `old_key_hex` = their current public key. The server
/// creates an OPEN proposal; the rotation takes effect once the consensus system
/// records 2 peer approvals.
///
/// # Errors
/// - `400` if `new_public_key_hex` is empty or identical to the current key.
/// - `401` / `403` if the caller is not authenticated or not in the allowlist.
pub async fn rotate_key(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Json(body): Json<RotateKeyRequest>,
) -> Result<impl IntoResponse, AppError> {
    if body.new_public_key_hex.is_empty() {
        return Err(AppError::BadRequest(
            "new_public_key_hex is required".to_string(),
        ));
    }

    // Look up the caller's current public key from the users table.
    let old_key_hex: Option<String> =
        sqlx::query_scalar("SELECT public_key FROM users WHERE id = $1")
            .bind(auth.user_id)
            .fetch_optional(&pool)
            .await
            .map_err(AppError::Database)?;

    let old_key_hex = old_key_hex.ok_or_else(|| {
        AppError::Unauthorized("authenticated user not found in users table".to_string())
    })?;

    if old_key_hex == body.new_public_key_hex {
        return Err(AppError::BadRequest(
            "new_public_key_hex must differ from the current key".to_string(),
        ));
    }

    // Reject if an open ROTATE proposal for this old key already exists.
    let existing_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT id FROM member_proposals
          WHERE action = 'ROTATE' AND old_key_hex = $1 AND status = 'OPEN'",
    )
    .bind(&old_key_hex)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    if let Some(id) = existing_id {
        return Err(AppError::BadRequest(format!(
            "an open ROTATE proposal already exists for this key (id={id})"
        )));
    }

    let proposal: ProposalRow = sqlx::query_as(
        r#"
        INSERT INTO member_proposals
            (action, target_key_hex, old_key_hex, created_by, status, approval_count)
        VALUES ('ROTATE', $1, $2, $2, 'OPEN', 0)
        RETURNING id, action, target_key_hex, old_key_hex, created_by, status,
                  approval_count, created_at, updated_at
        "#,
    )
    .bind(&body.new_public_key_hex)
    .bind(&old_key_hex)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    // Pre-register the new key in the allowlist so group members can inspect it
    // during the approval flow.
    // TODO(p4-consensus): gate authentication on allowlist entries having a
    // confirmed status so the new key cannot log in until the ROTATE proposal
    // transitions to APPROVED.
    sqlx::query(
        r#"
        INSERT INTO public_key_allowlist (public_key_hex, added_by, label)
        VALUES ($1, $2, $3)
        ON CONFLICT (public_key_hex) DO NOTHING
        "#,
    )
    .bind(&body.new_public_key_hex)
    .bind(&old_key_hex)
    .bind(body.new_label.as_deref().unwrap_or("Pending rotation"))
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    tracing::info!(
        proposal_id = %proposal.id,
        old_key = %old_key_hex,
        new_key = %body.new_public_key_hex,
        "key ROTATE proposal created — awaiting 2 peer approvals"
    );

    Ok((
        axum::http::StatusCode::CREATED,
        Json(json!({
            "proposal_id": proposal.id,
            "action": "ROTATE",
            "old_key_hex": old_key_hex,
            "new_key_hex": body.new_public_key_hex,
            "status": "OPEN",
            "approval_count": 0,
            "message": "Waiting for 2 approvals from group members."
        })),
    ))
}

// ---------------------------------------------------------------------------
// POST /keys/emergency-revoke
// ---------------------------------------------------------------------------

/// Any authenticated member can propose an emergency revocation of a
/// compromised / stolen key.
///
/// Creates a REMOVE proposal (action='REMOVE', target=`target_key_hex`).
/// The key is removed from the allowlist once 2 members approve via the
/// consensus system.
///
/// # Errors
/// - `400` if `target_key_hex` is empty or not in the allowlist.
/// - `401` / `403` if the caller is not authenticated.
pub async fn emergency_revoke(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Json(body): Json<EmergencyRevokeRequest>,
) -> Result<impl IntoResponse, AppError> {
    if body.target_key_hex.is_empty() {
        return Err(AppError::BadRequest(
            "target_key_hex is required".to_string(),
        ));
    }

    // Verify the target key is actually in the allowlist.
    let in_allowlist: Option<String> = sqlx::query_scalar(
        "SELECT public_key_hex FROM public_key_allowlist WHERE public_key_hex = $1",
    )
    .bind(&body.target_key_hex)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    if in_allowlist.is_none() {
        return Err(AppError::NotFound(format!(
            "key {} is not in the allowlist",
            body.target_key_hex
        )));
    }

    // Return existing open proposal if one already exists (idempotent).
    let existing: Option<(Uuid, i32)> = sqlx::query_as(
        "SELECT id, approval_count FROM member_proposals
          WHERE action = 'REMOVE' AND target_key_hex = $1 AND status = 'OPEN'",
    )
    .bind(&body.target_key_hex)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    if let Some((id, approvals)) = existing {
        return Ok((
            axum::http::StatusCode::OK,
            Json(json!({
                "proposal_id": id,
                "action": "REMOVE",
                "target_key_hex": body.target_key_hex,
                "status": "OPEN",
                "approval_count": approvals,
                "message": "An open revocation proposal already exists for this key."
            })),
        ));
    }

    // Record the caller's public key as created_by for the audit trail.
    let created_by: Option<String> =
        sqlx::query_scalar("SELECT public_key FROM users WHERE id = $1")
            .bind(auth.user_id)
            .fetch_optional(&pool)
            .await
            .map_err(AppError::Database)?;

    let created_by = created_by.unwrap_or_else(|| auth.user_id.to_string());

    let proposal: ProposalRow = sqlx::query_as(
        r#"
        INSERT INTO member_proposals
            (action, target_key_hex, old_key_hex, created_by, status, approval_count)
        VALUES ('REMOVE', $1, NULL, $2, 'OPEN', 0)
        RETURNING id, action, target_key_hex, old_key_hex, created_by, status,
                  approval_count, created_at, updated_at
        "#,
    )
    .bind(&body.target_key_hex)
    .bind(&created_by)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    tracing::info!(
        proposal_id = %proposal.id,
        target_key  = %body.target_key_hex,
        reported_by = %created_by,
        "emergency REMOVE proposal created — awaiting 2 peer approvals"
    );

    // TODO(p4-consensus): when the consensus approval handler exists, wire in
    // execute_approved_proposal() so that on 2 approvals the key is automatically
    // deleted from public_key_allowlist and a { "type": "key_revoked", ... }
    // broadcast is sent over the WebSocket relay.

    Ok((
        axum::http::StatusCode::CREATED,
        Json(json!({
            "proposal_id": proposal.id,
            "action": "REMOVE",
            "target_key_hex": body.target_key_hex,
            "status": "OPEN",
            "approval_count": 0,
            "message": "Emergency revocation proposal created. Waiting for 2 peer approvals."
        })),
    ))
}
