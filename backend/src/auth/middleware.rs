//! Axum auth middleware / extractor.
//!
//! Extracts a verified `AuthUser` from the `Authorization: Bearer <token>` header
//! by looking up the token in the in-memory SessionStore.

use axum::{
    async_trait,
    extract::{FromRef, FromRequestParts},
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use uuid::Uuid;

use super::challenge::SessionStore;

// BLOCKED(phase-2): AuthUser and AuthError are not yet wired to any route handler
// — add to handlers once protected routes are scaffolded.
#[allow(dead_code)]
/// The authenticated caller attached to request extensions after middleware runs.
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: Uuid,
}

/// Extractor error returned as JSON.
#[allow(dead_code)]
#[derive(Debug)]
pub struct AuthError(pub String);

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        (
            StatusCode::UNAUTHORIZED,
            Json(json!({ "error": self.0 })),
        )
            .into_response()
    }
}

// BLOCKED(phase-2): session lookup is node-local — replace SessionStore with a Redis
// client so all nodes share the same session state.
/// Axum extractor that validates the `Authorization: Bearer <token>` header
/// and resolves the caller's identity from the in-memory SessionStore.
#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    SessionStore: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or_else(|| AuthError("missing or malformed Authorization header".to_string()))?;

        let sessions = SessionStore::from_ref(state);
        let map = sessions.0.lock().expect("session store poisoned");
        let user_id = map
            .get(token)
            .map(|entry| entry.user_id)
            .ok_or_else(|| AuthError("invalid or expired session token".to_string()))?;

        Ok(AuthUser { user_id })
    }
}
