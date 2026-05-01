use axum::{
    extract::{Path, State},
    Json,
};
use serde::Deserialize;
use uuid::Uuid;

use crate::{
    auth::middleware::AuthUser,
    db::DbPool,
    error::AppError,
};
use super::models::UserProfile;

#[derive(Debug, Deserialize)]
pub struct UpdateProfileBody {
    pub bio: String,
    pub skills: Vec<String>,
}

/// GET /users/me/profile — returns own profile
pub async fn get_own_profile(
    auth: AuthUser,
    State(pool): State<DbPool>,
) -> Result<Json<UserProfile>, AppError> {
    let profile = UserProfile::get(&pool, auth.user_id)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(profile))
}

/// GET /users/:id/profile — returns any user's profile
/// BLOCKED(phase-2): group membership check not yet enforced here
pub async fn get_profile(
    _auth: AuthUser,
    State(pool): State<DbPool>,
    Path(user_id): Path<Uuid>,
) -> Result<Json<UserProfile>, AppError> {
    let profile = UserProfile::get(&pool, user_id)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(profile))
}

/// GET /groups/me/members — returns all profiles for the caller's group
/// (used for skills directory / "who can help me with X")
pub async fn list_group_members(
    auth: AuthUser,
    State(pool): State<DbPool>,
) -> Result<Json<Vec<UserProfile>>, AppError> {
    // Fetch the caller's group_id first.
    let row = sqlx::query_as::<_, (Option<Uuid>,)>(
        "SELECT group_id FROM users WHERE id = $1",
    )
    .bind(auth.user_id)
    .fetch_optional(&pool)
    .await?
    .ok_or(AppError::NotFound)?;

    let group_id = row.0.ok_or_else(|| AppError::BadRequest("user has no group".to_string()))?;

    let members = UserProfile::list_for_group(&pool, group_id).await?;
    Ok(Json(members))
}

/// PUT /users/me/profile
/// Body: { "bio": "string", "skills": ["skill1", "skill2"] }
/// Returns updated profile
pub async fn update_profile(
    auth: AuthUser,
    State(pool): State<DbPool>,
    Json(body): Json<UpdateProfileBody>,
) -> Result<Json<UserProfile>, AppError> {
    UserProfile::update(&pool, auth.user_id, body.bio, body.skills).await?;

    let profile = UserProfile::get(&pool, auth.user_id)
        .await?
        .ok_or(AppError::NotFound)?;
    Ok(Json(profile))
}
