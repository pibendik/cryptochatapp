//! MLS key rotation HTTP handlers.
//!
//! All endpoints store and forward opaque blobs — no MLS validation is performed
//! here yet. Phase 4 will integrate the `openmls` crate for actual key material
//! validation and epoch management.
//!
// BLOCKED(mls-phase-4): openmls crate integration — currently stores/forwards opaque blobs only.

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use axum::extract::ws::Message;
use base64::{engine::general_purpose::STANDARD, Engine};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;
use crate::mls::delivery::{MlsDeliveryService, MlsMessageType};
use crate::relay::ws_handler::ConnectionMap;

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct UploadKeyPackageRequest {
    /// Base64-encoded TLS-serialised MLS KeyPackage blob.
    pub key_package_data: String,
    pub group_id: String,
}

#[derive(Debug, Serialize)]
pub struct KeyPackageResponse {
    pub id: Uuid,
    pub owner_public_key_hex: String,
    pub group_id: String,
    pub key_package_data: String, // base64-encoded blob
    pub epoch: i64,
    pub created_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct SubmitCommitRequest {
    pub group_id: String,
    pub epoch: i64,
    /// Base64-encoded serialised MLS Commit message.
    // BLOCKED(mls-phase-4): validate as a real openmls Commit before storing and broadcasting.
    pub commit_data: String,
}

#[derive(Debug, Serialize)]
pub struct CommitResponse {
    pub id: Uuid,
    pub group_id: String,
    pub epoch: i64,
    pub commit_data: String, // base64-encoded blob
    pub created_by: String,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct SinceEpochQuery {
    pub since_epoch: Option<i64>,
}

// ---------------------------------------------------------------------------
// DB row helpers
// ---------------------------------------------------------------------------

#[derive(sqlx::FromRow)]
struct KeyPackageRow {
    id: Uuid,
    owner_public_key_hex: String,
    group_id: String,
    key_package_data: Vec<u8>,
    epoch: i64,
    created_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
}

#[derive(sqlx::FromRow)]
struct CommitRow {
    id: Uuid,
    group_id: String,
    epoch: i64,
    commit_data: Vec<u8>,
    created_by: String,
    created_at: DateTime<Utc>,
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// POST /mls/key-packages — upload a new KeyPackage for a group.
///
/// The KeyPackage blob is validated with openmls (signature + lifetime) before
/// storage.  The caller's public key (looked up from their user record) is used
/// as `owner_public_key_hex`. An existing KeyPackage for the same
/// (owner, group_id) pair is replaced.
pub async fn upload_key_package(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Json(body): Json<UploadKeyPackageRequest>,
) -> Result<impl IntoResponse, AppError> {
    let key_package_bytes = STANDARD
        .decode(&body.key_package_data)
        .map_err(|e| AppError::BadRequest(format!("invalid base64 key_package_data: {e}")))?;

    // Validate: TLS-deserialise, verify leaf-node signature, and check lifetime.
    MlsDeliveryService::validate_key_package(&key_package_bytes)
        .map_err(|e| AppError::BadRequest(format!("invalid key package: {e}")))?;

    // Look up the caller's public key hex (needed for the FK into public_key_allowlist).
    let owner_public_key_hex: String =
        sqlx::query_scalar("SELECT public_key FROM users WHERE id = $1")
            .bind(auth.user_id)
            .fetch_optional(&pool)
            .await
            .map_err(AppError::Database)?
            .ok_or_else(|| AppError::NotFound("authenticated user not found".into()))?;

    let row = sqlx::query_as::<_, KeyPackageRow>(
        "INSERT INTO mls_key_packages
           (owner_public_key_hex, group_id, key_package_data)
         VALUES ($1, $2, $3)
         ON CONFLICT (owner_public_key_hex, group_id)
           DO UPDATE SET key_package_data = EXCLUDED.key_package_data,
                         created_at       = NOW(),
                         expires_at       = NOW() + INTERVAL '7 days'
         RETURNING id, owner_public_key_hex, group_id, key_package_data, epoch, created_at, expires_at",
    )
    .bind(&owner_public_key_hex)
    .bind(&body.group_id)
    .bind(&key_package_bytes)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    Ok((StatusCode::CREATED, Json(row_to_kp_response(row))))
}

/// GET /mls/key-packages/:group_id — fetch all current (non-expired) KeyPackages for a group.
///
/// Used by a group admin to collect KeyPackages for all members before
/// constructing a Welcome or Commit message.
// BLOCKED(mls-client-phase-4): client-side MLS state machine — callers use
// these blobs directly with their local openmls instance to build Welcome/Commit.
pub async fn get_key_packages(
    State(pool): State<DbPool>,
    _auth: AuthUser,
    Path(group_id): Path<String>,
) -> Result<impl IntoResponse, AppError> {
    let rows = sqlx::query_as::<_, KeyPackageRow>(
        "SELECT id, owner_public_key_hex, group_id, key_package_data, epoch, created_at, expires_at
           FROM mls_key_packages
          WHERE group_id = $1
            AND expires_at > NOW()
          ORDER BY created_at ASC",
    )
    .bind(&group_id)
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    let response: Vec<KeyPackageResponse> = rows.into_iter().map(row_to_kp_response).collect();
    Ok(Json(response))
}

/// POST /mls/commits — submit a new Commit (member add/remove/update).
///
/// The blob is classified by MLS message type:
/// - `Welcome`        → stored and broadcast; TODO per-recipient routing once
///                      key-package directory is queryable by KeyPackageRef.
/// - `PublicMessage`  → stored and broadcast to all group members.
/// - `PrivateMessage` → stored and broadcast to all group members.
/// - Unknown/malformed → rejected with 400.
///
/// // BLOCKED(mls-client-phase-4): client-side MLS state machine — clients
/// // apply the Commit via their local openmls instance to advance epoch state.
/// // The epoch transition (Commit + Update/Remove) must be applied atomically
/// // by the client; the server only stores the blob.
pub async fn submit_commit(
    State(pool): State<DbPool>,
    State(connections): State<ConnectionMap>,
    auth: AuthUser,
    Json(body): Json<SubmitCommitRequest>,
) -> Result<impl IntoResponse, AppError> {
    let commit_bytes = STANDARD
        .decode(&body.commit_data)
        .map_err(|e| AppError::BadRequest(format!("invalid base64 commit_data: {e}")))?;

    // Classify the blob to validate it is a recognised MLS message type.
    let msg_type = MlsDeliveryService::classify_message(&commit_bytes);
    if msg_type == MlsMessageType::Unknown {
        return Err(AppError::BadRequest(
            "unrecognised or malformed MLS message blob".into(),
        ));
    }

    tracing::debug!(
        group_id = %body.group_id,
        epoch = body.epoch,
        msg_type = ?msg_type,
        "mls message classified for routing"
    );

    let created_by = auth.user_id.to_string();

    let row = sqlx::query_as::<_, CommitRow>(
        "INSERT INTO mls_commits (group_id, epoch, commit_data, created_by)
         VALUES ($1, $2, $3, $4)
         RETURNING id, group_id, epoch, commit_data, created_by, created_at",
    )
    .bind(&body.group_id)
    .bind(body.epoch)
    .bind(&commit_bytes)
    .bind(&created_by)
    .fetch_one(&pool)
    .await
    .map_err(AppError::Database)?;

    // Broadcast the MLS message to all connected group members.
    // Welcome messages ideally route only to new-member recipients (by
    // KeyPackageRef); for now we broadcast to the group as a safe fallback.
    // TODO(mls-welcome-routing): route Welcome per-recipient using kp_refs.
    // BLOCKED(mls-client-phase-4): client-side MLS state machine — clients
    // apply the received message via their local openmls instance.
    broadcast_mls_commit(&pool, &connections, &body.group_id, body.epoch, &body.commit_data).await;

    Ok((StatusCode::CREATED, Json(row_to_commit_response(row))))
}

/// GET /mls/commits/:group_id?since_epoch=N — fetch Commit history since epoch N.
///
/// Clients use this to catch up after a reconnect or missed epoch transition.
// BLOCKED(mls-client-phase-4): clients apply these blobs via their local
// openmls instance to advance group state epoch by epoch.
pub async fn get_commits(
    State(pool): State<DbPool>,
    _auth: AuthUser,
    Path(group_id): Path<String>,
    Query(params): Query<SinceEpochQuery>,
) -> Result<impl IntoResponse, AppError> {
    let since = params.since_epoch.unwrap_or(0);

    let rows = sqlx::query_as::<_, CommitRow>(
        "SELECT id, group_id, epoch, commit_data, created_by, created_at
           FROM mls_commits
          WHERE group_id = $1
            AND epoch >= $2
          ORDER BY epoch ASC",
    )
    .bind(&group_id)
    .bind(since)
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    let response: Vec<CommitResponse> = rows.into_iter().map(row_to_commit_response).collect();
    Ok(Json(response))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn row_to_kp_response(row: KeyPackageRow) -> KeyPackageResponse {
    KeyPackageResponse {
        id: row.id,
        owner_public_key_hex: row.owner_public_key_hex,
        group_id: row.group_id,
        key_package_data: STANDARD.encode(&row.key_package_data),
        epoch: row.epoch,
        created_at: row.created_at,
        expires_at: row.expires_at,
    }
}

fn row_to_commit_response(row: CommitRow) -> CommitResponse {
    CommitResponse {
        id: row.id,
        group_id: row.group_id,
        epoch: row.epoch,
        commit_data: STANDARD.encode(&row.commit_data),
        created_by: row.created_by,
        created_at: row.created_at,
    }
}

/// Broadcast a serialised MLS message event to all currently-connected members
/// of `group_id`.
///
/// Group membership is resolved from the `users` table by parsing `group_id`
/// as a UUID.  If `group_id` is not a valid UUID (e.g., a future non-UUID MLS
/// group identifier), the broadcast is silently skipped.
// BLOCKED(mls-client-phase-4): replace UUID-based group lookup with MLS tree
// membership once clients maintain the ratchet tree locally.
async fn broadcast_mls_commit(
    pool: &DbPool,
    connections: &ConnectionMap,
    group_id: &str,
    epoch: i64,
    commit_data_b64: &str,
) {
    let group_uuid = match group_id.parse::<Uuid>() {
        Ok(u) => u,
        Err(_) => {
            tracing::warn!(group_id, "mls_commit broadcast skipped: group_id is not a UUID");
            return;
        }
    };

    let member_ids: Vec<Uuid> =
        match sqlx::query_scalar::<_, Uuid>("SELECT id FROM users WHERE group_id = $1")
            .bind(group_uuid)
            .fetch_all(pool)
            .await
        {
            Ok(ids) => ids,
            Err(e) => {
                tracing::error!(error = %e, "mls_commit broadcast: failed to fetch group members");
                return;
            }
        };

    let payload = serde_json::json!({
        "type": "mls_commit",
        "groupId": group_id,
        "epoch": epoch,
        "commitData": commit_data_b64,
    });
    let json = serde_json::to_string(&payload).unwrap_or_default();

    let senders = {
        let guard = connections.read().await;
        member_ids
            .iter()
            .filter_map(|mid| guard.get(mid).cloned())
            .collect::<Vec<_>>()
    };

    for tx in senders {
        if let Err(e) = tx.try_send(Message::Text(json.clone())) {
            tracing::warn!("mls_commit broadcast: channel full, message dropped: {e}");
        }
    }
}
