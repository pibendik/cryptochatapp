use uuid::Uuid;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, FromRow};

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct UserProfile {
    pub user_id: Uuid,
    pub display_name: String,
    pub bio: String,
    pub skills: Vec<String>,      // plaintext — explicitly public within group
    pub availability: String,
    pub public_key: String,       // hex Ed25519 — needed for key verification
    pub encryption_public_key: Option<String>, // hex X25519
}

impl UserProfile {
    pub async fn get(pool: &PgPool, user_id: Uuid) -> Result<Option<Self>, sqlx::Error> {
        sqlx::query_as::<_, UserProfile>(
            r#"SELECT id as user_id, display_name,
                      COALESCE(bio, '') as bio,
                      COALESCE(skills, '{}') as skills,
                      COALESCE(availability, 'online') as availability,
                      public_key,
                      encryption_public_key
               FROM users WHERE id = $1"#,
        )
        .bind(user_id)
        .fetch_optional(pool)
        .await
    }

    pub async fn list_for_group(pool: &PgPool, group_id: Uuid) -> Result<Vec<Self>, sqlx::Error> {
        sqlx::query_as::<_, UserProfile>(
            r#"SELECT id as user_id, display_name,
                      COALESCE(bio, '') as bio,
                      COALESCE(skills, '{}') as skills,
                      COALESCE(availability, 'online') as availability,
                      public_key,
                      encryption_public_key
               FROM users WHERE group_id = $1"#,
        )
        .bind(group_id)
        .fetch_all(pool)
        .await
    }

    pub async fn update(
        pool: &PgPool,
        user_id: Uuid,
        bio: String,
        skills: Vec<String>,
    ) -> Result<(), sqlx::Error> {
        sqlx::query("UPDATE users SET bio = $1, skills = $2 WHERE id = $3")
            .bind(bio)
            .bind(skills)
            .bind(user_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}

