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
        display_name: String,
        // bio and skills intentionally NOT stored server-side — lives on device only
    ) -> Result<(), sqlx::Error> {
        sqlx::query("UPDATE users SET display_name = $1 WHERE id = $2")
            .bind(display_name)
            .bind(user_id)
            .execute(pool)
            .await?;
        Ok(())
    }
}

