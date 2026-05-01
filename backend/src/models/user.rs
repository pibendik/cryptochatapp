use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// A registered user identified by their Ed25519 public key.
///
/// No passwords — authentication is always challenge-response.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    /// Hex-encoded Ed25519 signing public key (32 bytes / 64 hex chars).
    pub public_key: String,
    /// Hex-encoded X25519 encryption public key (32 bytes / 64 hex chars).
    pub encryption_public_key: Option<String>,
    /// The group this user belongs to (nullable).
    pub group_id: Option<Uuid>,
    pub display_name: String,
    pub created_at: DateTime<Utc>,
}

/// Row representation for DB reads, mapped directly from sqlx.
#[derive(Debug, FromRow)]
pub struct UserRow {
    pub id: Uuid,
    pub public_key: String,
    pub encryption_public_key: Option<String>,
    pub group_id: Option<Uuid>,
    pub display_name: String,
    pub created_at: DateTime<Utc>,
}

impl From<UserRow> for User {
    fn from(row: UserRow) -> Self {
        Self {
            id: row.id,
            public_key: row.public_key,
            encryption_public_key: row.encryption_public_key,
            group_id: row.group_id,
            display_name: row.display_name,
            created_at: row.created_at,
        }
    }
}

impl User {
    /// Upsert a user by public key.
    ///
    /// Inserts a new row on first auth; updates `encryption_public_key` and `display_name`
    /// on subsequent logins (e.g. after a key rotation or display-name change).
    ///
    // BLOCKED(allowlist): self-registration is open to any valid Ed25519 key — add a
    // server-side public-key allowlist check here before first production deployment.
    pub async fn upsert(
        pool: &sqlx::PgPool,
        public_key: &str,
        encryption_public_key: &str,
        display_name: &str,
    ) -> Result<User, sqlx::Error> {
        let row = sqlx::query_as::<_, UserRow>(
            r#"
            INSERT INTO users (public_key, encryption_public_key, display_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (public_key) DO UPDATE
                SET encryption_public_key = EXCLUDED.encryption_public_key,
                    display_name          = EXCLUDED.display_name
            RETURNING id, public_key, encryption_public_key, display_name, group_id, created_at
            "#,
        )
        .bind(public_key)
        .bind(encryption_public_key)
        .bind(display_name)
        .fetch_one(pool)
        .await?;

        Ok(row.into())
    }
}
