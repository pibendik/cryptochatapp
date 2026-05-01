use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// BLOCKED(phase-2): Group and GroupRow not yet used — implement group CRUD helpers
// and wire to route handlers in Phase 2.
#[allow(dead_code)]
/// A chat group.
///
/// `name` is stored as `BYTEA` (client-side encrypted) in the DB so the
/// server never learns the plaintext group name.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Group {
    pub id: Uuid,
    /// Encrypted group name — hex-encoded ciphertext for JSON transport.
    pub name: String,
    pub created_at: DateTime<Utc>,
}

/// Row representation for DB reads (name as raw bytes from BYTEA column).
#[allow(dead_code)]
#[derive(Debug)]
pub struct GroupRow {
    pub id: Uuid,
    /// Raw BYTEA bytes from PostgreSQL.
    pub name: Vec<u8>,
    pub created_at: DateTime<Utc>,
}

impl From<GroupRow> for Group {
    fn from(row: GroupRow) -> Self {
        Self {
            id: row.id,
            name: hex::encode(row.name),
            created_at: row.created_at,
        }
    }
}

// BLOCKED(phase-2): group CRUD helpers not yet implemented — add find_by_id,
// create_group, list_members, add_member, remove_member once migrations are in place.
// BLOCKED(phase-3): group membership changes (add/remove) require MLS epoch rotation
// — coordinate with the MLS key-package flow in Phase 3.
