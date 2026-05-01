use chrono::{DateTime, Utc};
use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct ForumPost {
    pub id: Uuid,
    pub author_id: Uuid,
    pub group_id: Uuid,     // posts are scoped to the author's group
    pub title: String,      // plaintext title — short, not sensitive
    pub payload: Vec<u8>,   // encrypted body — ALWAYS ciphertext
    pub resolved: bool,
    pub created_at: DateTime<Utc>,
}

impl ForumPost {
    pub async fn create(
        pool: &PgPool,
        author_id: Uuid,
        group_id: Uuid,
        title: String,
        payload: Vec<u8>,
    ) -> Result<Self, sqlx::Error> {
        sqlx::query_as::<_, ForumPost>(
            r#"INSERT INTO forum_posts (id, author_id, group_id, title, payload, resolved, created_at)
               VALUES ($1, $2, $3, $4, $5, false, NOW())
               RETURNING id, author_id, group_id, title, payload, resolved, created_at"#,
        )
        .bind(Uuid::new_v4())
        .bind(author_id)
        .bind(group_id)
        .bind(title)
        .bind(payload)
        .fetch_one(pool)
        .await
    }

    pub async fn list_for_group(pool: &PgPool, group_id: Uuid) -> Result<Vec<Self>, sqlx::Error> {
        sqlx::query_as::<_, ForumPost>(
            r#"SELECT id, author_id, group_id, title, payload, resolved, created_at
               FROM forum_posts WHERE group_id = $1
               ORDER BY created_at DESC LIMIT 100"#,
        )
        .bind(group_id)
        .fetch_all(pool)
        .await
    }

    pub async fn resolve(
        pool: &PgPool,
        id: Uuid,
        _requester_id: Uuid, // BLOCKED(phase-2): verify requester is in same group before resolving
    ) -> Result<bool, sqlx::Error> {
        let result = sqlx::query(
            "UPDATE forum_posts SET resolved = true WHERE id = $1 AND resolved = false",
        )
        .bind(id)
        .execute(pool)
        .await?;
        Ok(result.rows_affected() > 0)
    }
}
