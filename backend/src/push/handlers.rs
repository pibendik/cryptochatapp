//! Push-token registration endpoints.
//!
//! POST  /push/register  — store or update the device token for the caller.
//! DELETE /push/register — remove the device token on logout.

use axum::{extract::State, http::StatusCode, Json};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;

#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    /// Device push token (APNs hex token or FCM registration token).
    pub token: String,
    /// Platform identifier: `"apns"` or `"fcm"`.
    pub platform: String,
}

#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub registered: bool,
}

/// POST /push/register
///
/// Stores (or updates) the caller's device token in the database.
/// The token is keyed on `(public_key_hex, platform)` so a user can have one
/// APNs token and one FCM token simultaneously (e.g. tablet + phone).
pub async fn register_token(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Json(body): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<Value>), AppError> {
    if body.platform != "apns" && body.platform != "fcm" {
        return Err(AppError::BadRequest(
            "platform must be 'apns' or 'fcm'".into(),
        ));
    }

    // Resolve the caller's public_key_hex from their user_id.
    let public_key_hex: Option<String> = sqlx::query_scalar(
        r#"SELECT encode(decode(u.public_key, 'base64'), 'hex')
           FROM users u
           WHERE u.id = $1"#,
    )
    .bind(auth.user_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    let public_key_hex = public_key_hex
        .ok_or_else(|| AppError::NotFound("user not found".into()))?;

    sqlx::query(
        r#"INSERT INTO device_tokens (public_key_hex, platform, token, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (public_key_hex, platform)
           DO UPDATE SET token = EXCLUDED.token, updated_at = NOW()"#,
    )
    .bind(&public_key_hex)
    .bind(&body.platform)
    .bind(&body.token)
    .execute(&pool)
    .await
    .map_err(AppError::Database)?;

    Ok((StatusCode::OK, Json(json!({ "registered": true }))))
}

/// DELETE /push/register
///
/// Removes the caller's device token(s) on logout.  Passing a `platform` body
/// removes only that platform's token; omitting it removes all tokens for the user.
pub async fn unregister_token(
    State(pool): State<DbPool>,
    auth: AuthUser,
    body: Option<Json<UnregisterRequest>>,
) -> Result<(StatusCode, Json<Value>), AppError> {
    // Resolve the caller's public_key_hex.
    let public_key_hex: Option<String> = sqlx::query_scalar(
        r#"SELECT encode(decode(u.public_key, 'base64'), 'hex')
           FROM users u
           WHERE u.id = $1"#,
    )
    .bind(auth.user_id)
    .fetch_optional(&pool)
    .await
    .map_err(AppError::Database)?;

    let public_key_hex = public_key_hex
        .ok_or_else(|| AppError::NotFound("user not found".into()))?;

    match body.and_then(|b| b.platform.clone()) {
        Some(platform) => {
            sqlx::query(
                "DELETE FROM device_tokens WHERE public_key_hex = $1 AND platform = $2",
            )
            .bind(&public_key_hex)
            .bind(&platform)
            .execute(&pool)
            .await
            .map_err(AppError::Database)?;
        }
        None => {
            sqlx::query("DELETE FROM device_tokens WHERE public_key_hex = $1")
                .bind(&public_key_hex)
                .execute(&pool)
                .await
                .map_err(AppError::Database)?;
        }
    }

    Ok((StatusCode::OK, Json(json!({ "unregistered": true }))))
}

#[derive(Debug, Deserialize)]
pub struct UnregisterRequest {
    pub platform: Option<String>,
}
