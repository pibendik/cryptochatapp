use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use base64::{engine::general_purpose::STANDARD, Engine};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::auth::middleware::AuthUser;
use crate::db::DbPool;
use crate::error::AppError;
use super::models::ForumPost;

#[derive(Debug, Deserialize)]
pub struct CreatePostRequest {
    pub title: String,   // base64-encoded ECIES ciphertext
    pub payload: String, // base64-encoded ciphertext
}

#[derive(Debug, Serialize)]
pub struct ForumPostResponse {
    pub id: Uuid,
    pub author_id: Uuid,
    pub group_id: Uuid,
    pub title: String,   // base64-encoded ECIES ciphertext
    pub payload: String, // base64-encoded ciphertext
    pub resolved: bool,
    pub created_at: DateTime<Utc>,
}

impl From<ForumPost> for ForumPostResponse {
    fn from(post: ForumPost) -> Self {
        Self {
            id: post.id,
            author_id: post.author_id,
            group_id: post.group_id,
            title: STANDARD.encode(&post.title),
            payload: STANDARD.encode(&post.payload),
            resolved: post.resolved,
            created_at: post.created_at,
        }
    }
}

#[derive(sqlx::FromRow)]
struct GroupIdRow {
    group_id: Option<Uuid>,
}

async fn get_user_group_id(pool: &DbPool, user_id: Uuid) -> Result<Uuid, AppError> {
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
        None => Err(AppError::NotFound("user not found".into())),
    }
}

/// POST /forum/posts — create a new forum post in the caller's group.
pub async fn create_post(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Json(body): Json<CreatePostRequest>,
) -> Result<impl IntoResponse, AppError> {
    let group_id = get_user_group_id(&pool, auth.user_id).await?;

    let payload = STANDARD
        .decode(&body.payload)
        .map_err(|e| AppError::BadRequest(format!("invalid base64 payload: {e}")))?;

    let title = STANDARD
        .decode(&body.title)
        .map_err(|e| AppError::BadRequest(format!("invalid base64 title: {e}")))?;

    let post = ForumPost::create(&pool, auth.user_id, group_id, title, payload)
        .await
        .map_err(AppError::Database)?;

    Ok((StatusCode::CREATED, Json(ForumPostResponse::from(post))))
}

/// GET /forum/posts — list all posts in the caller's group.
pub async fn list_posts(
    State(pool): State<DbPool>,
    auth: AuthUser,
) -> Result<impl IntoResponse, AppError> {
    let group_id = get_user_group_id(&pool, auth.user_id).await?;

    let posts = ForumPost::list_for_group(&pool, group_id)
        .await
        .map_err(AppError::Database)?;

    let response: Vec<ForumPostResponse> =
        posts.into_iter().map(ForumPostResponse::from).collect();

    Ok(Json(response))
}

/// PATCH /forum/posts/:id/resolve — mark a post as resolved.
pub async fn resolve_post(
    State(pool): State<DbPool>,
    auth: AuthUser,
    Path(id): Path<Uuid>,
) -> Result<impl IntoResponse, AppError> {
    let resolved = ForumPost::resolve(&pool, id, auth.user_id)
        .await
        .map_err(AppError::Database)?;

    if resolved {
        Ok((StatusCode::OK, Json(serde_json::json!({ "resolved": true }))))
    } else {
        Err(AppError::NotFound("forum post not found".into()))
    }
}
