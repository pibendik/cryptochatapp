//! Admin endpoints for managing the public key allowlist.
//!
//! All routes are protected by `AdminAuth`, which accepts an
//! `Authorization: Bearer <public_key_hex>` header and checks that the key
//! is either the `BOOTSTRAP_ADMIN_KEY` env var or already present in the
//! `public_key_allowlist` table.

use axum::{
    async_trait,
    extract::{FromRef, FromRequestParts, Path, State},
    http::{request::Parts, StatusCode},
    response::IntoResponse,
    Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::db::DbPool;
use crate::error::AppError;

// ---------------------------------------------------------------------------
// Row type
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct AllowlistEntry {
    pub public_key_hex: String,
    pub added_by: String,
    pub added_at: DateTime<Utc>,
    pub label: Option<String>,
}

// ---------------------------------------------------------------------------
// AdminAuth extractor
// ---------------------------------------------------------------------------

/// Extractor that validates admin access for allowlist management routes.
///
/// Accepts `Authorization: Bearer <public_key_hex>` and checks:
/// 1. Whether the key matches the `BOOTSTRAP_ADMIN_KEY` env var, OR
/// 2. Whether the key already exists in `public_key_allowlist`.
pub struct AdminAuth {
    pub public_key_hex: String,
}

#[async_trait]
impl<S> FromRequestParts<S> for AdminAuth
where
    DbPool: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or_else(|| {
                AppError::Unauthorized("missing or malformed Authorization header".to_string())
            })?
            .to_string();

        // Fast path: bootstrap admin key (checked before DB to allow access when list is empty).
        if let Ok(bk) = std::env::var("BOOTSTRAP_ADMIN_KEY") {
            if !bk.is_empty() && token == bk {
                return Ok(AdminAuth { public_key_hex: token });
            }
        }

        // Check whether the key is in the allowlist.
        let pool = DbPool::from_ref(state);
        let row = sqlx::query("SELECT 1 FROM public_key_allowlist WHERE public_key_hex = $1")
            .bind(&token)
            .fetch_optional(&pool)
            .await
            .map_err(AppError::Database)?;

        if row.is_some() {
            Ok(AdminAuth { public_key_hex: token })
        } else {
            Err(AppError::Unauthorized(
                "key not authorized to manage allowlist".to_string(),
            ))
        }
    }
}

// ---------------------------------------------------------------------------
// Request bodies
// ---------------------------------------------------------------------------

#[derive(Debug, Deserialize)]
pub struct AddKeyRequest {
    pub public_key_hex: String,
    pub label: Option<String>,
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// GET /admin/allowlist — list all approved public keys.
pub async fn list_allowlist(
    State(pool): State<DbPool>,
    _auth: AdminAuth,
) -> Result<impl IntoResponse, AppError> {
    let entries = sqlx::query_as::<_, AllowlistEntry>(
        "SELECT public_key_hex, added_by, added_at, label FROM public_key_allowlist ORDER BY added_at ASC",
    )
    .fetch_all(&pool)
    .await
    .map_err(AppError::Database)?;

    Ok(Json(entries))
}

/// POST /admin/allowlist — add a public key to the allowlist.
pub async fn add_to_allowlist(
    State(pool): State<DbPool>,
    auth: AdminAuth,
    Json(body): Json<AddKeyRequest>,
) -> Result<impl IntoResponse, AppError> {
    if body.public_key_hex.is_empty() {
        return Err(AppError::BadRequest("public_key_hex is required".to_string()));
    }

    sqlx::query(
        "INSERT INTO public_key_allowlist (public_key_hex, added_by, label)
         VALUES ($1, $2, $3)
         ON CONFLICT (public_key_hex) DO UPDATE SET label = EXCLUDED.label, added_by = EXCLUDED.added_by",
    )
    .bind(&body.public_key_hex)
    .bind(&auth.public_key_hex)
    .bind(&body.label)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    tracing::info!(key = %body.public_key_hex, added_by = %auth.public_key_hex, "key added to allowlist");
    Ok((StatusCode::CREATED, Json(json!({ "added": true, "public_key_hex": body.public_key_hex }))))
}

/// DELETE /admin/allowlist/:key_hex — remove a public key from the allowlist.
pub async fn remove_from_allowlist(
    State(pool): State<DbPool>,
    _auth: AdminAuth,
    Path(key_hex): Path<String>,
) -> Result<impl IntoResponse, AppError> {
    let result = sqlx::query("DELETE FROM public_key_allowlist WHERE public_key_hex = $1")
        .bind(&key_hex)
        .execute(&pool)
        .await
        .map_err(AppError::Database)?;

    if result.rows_affected() == 0 {
        return Err(AppError::NotFound(format!("key {key_hex} not in allowlist")));
    }

    tracing::info!(key = %key_hex, "key removed from allowlist");
    Ok(Json(json!({ "removed": true, "public_key_hex": key_hex })))
}
