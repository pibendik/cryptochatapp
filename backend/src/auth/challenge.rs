//! Ed25519 challenge-response authentication.
//!
//! Flow:
//!   1. Client calls POST /auth/challenge with their public key (hex).
//!   2. Server generates a UUID challenge_id + 32 random bytes, stores with TTL, returns both.
//!   3. Client signs the challenge bytes with their Ed25519 private key and calls POST /auth/verify.
//!   4. Server verifies the signature; on success upserts user and returns a session token.

use ed25519_dalek::{Signature, VerifyingKey};
use rand::RngCore;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tracing::instrument;
use uuid::Uuid;

/// A pending challenge stored server-side, keyed by challenge_id.
#[derive(Debug, Clone)]
pub struct PendingChallenge {
    /// Hex-encoded Ed25519 public key that requested this challenge.
    pub public_key: String,
    pub nonce: Vec<u8>,
    pub issued_at: Instant,
    pub ttl: Duration,
    pub used: bool,
}

impl PendingChallenge {
    pub fn is_expired(&self) -> bool {
        self.issued_at.elapsed() > self.ttl
    }
}

// BLOCKED(phase-2): in-memory challenge store is node-local — replace with Redis for
// multi-node deployments so challenges are visible to all instances.
/// In-memory challenge store. Key = challenge_id (UUID string).
#[derive(Debug, Clone, Default)]
pub struct ChallengeStore(pub Arc<Mutex<HashMap<String, PendingChallenge>>>);

impl ChallengeStore {
    pub fn new() -> Self {
        Self::default()
    }
}

/// A live session entry, keyed by session token (hex string).
#[derive(Debug, Clone)]
pub struct SessionEntry {
    pub user_id: Uuid,
    pub created_at: Instant,
}

// BLOCKED(phase-2): in-memory session store is node-local — replace with Redis for
// multi-node deployments so sessions are shared across instances.
/// In-memory session store. Key = session token (hex string), value = `SessionEntry`.
#[derive(Debug, Clone, Default)]
pub struct SessionStore(pub Arc<Mutex<HashMap<String, SessionEntry>>>);

impl SessionStore {
    pub fn new() -> Self {
        Self::default()
    }
}

/// Request body for POST /auth/challenge.
#[derive(Debug, Deserialize)]
pub struct ChallengeRequest {
    /// Hex-encoded Ed25519 public key (32 bytes → 64 hex chars).
    pub public_key: String,
}

/// Response body for POST /auth/challenge.
#[derive(Debug, Serialize)]
pub struct ChallengeResponse {
    /// UUID identifying this challenge server-side.
    pub challenge_id: String,
    /// Hex-encoded 32-byte random challenge bytes to sign.
    pub challenge: String,
}

/// Request body for POST /auth/verify.
#[derive(Debug, Deserialize)]
pub struct VerifyRequest {
    /// challenge_id returned by POST /auth/challenge.
    pub challenge_id: String,
    /// Hex-encoded Ed25519 signature (64 bytes) over the challenge bytes.
    pub signature: String,
    /// Display name for the user account.
    pub display_name: String,
    /// Hex-encoded X25519 public key (32 bytes) for message encryption.
    pub encryption_public_key: String,
}

/// Response body for POST /auth/verify.
#[derive(Debug, Serialize)]
pub struct VerifyResponse {
    pub session_token: String,
    pub user_id: Uuid,
}

/// Issue a new challenge for the given public key.
///
/// Stores the challenge in the in-memory store keyed by a fresh UUID.
/// Returns the challenge_id and hex-encoded challenge bytes.
#[instrument(skip(store))]
pub fn issue_challenge(
    store: &ChallengeStore,
    public_key_hex: &str,
    ttl: Duration,
) -> ChallengeResponse {
    let mut nonce = vec![0u8; 32];
    rand::thread_rng().fill_bytes(&mut nonce);

    let challenge_id = Uuid::new_v4().to_string();
    let challenge_hex = hex::encode(&nonce);

    {
        let mut map = store.0.lock().expect("challenge store poisoned");
        map.insert(
            challenge_id.clone(),
            PendingChallenge {
                public_key: public_key_hex.to_string(),
                nonce,
                issued_at: Instant::now(),
                ttl,
                used: false,
            },
        );
    }

    tracing::debug!(public_key = %public_key_hex, challenge_id = %challenge_id, "challenge issued");
    ChallengeResponse { challenge_id, challenge: challenge_hex }
}

/// Verify a challenge-response signature.
///
/// Looks up the challenge by `challenge_id`, checks expiry and single-use,
/// then verifies the Ed25519 signature over the original challenge bytes.
///
/// Returns the hex-encoded public key on success so the caller can upsert/look up the user.
#[instrument(skip(store))]
pub fn verify_challenge(
    store: &ChallengeStore,
    challenge_id: &str,
    signature_hex: &str,
) -> Result<String, String> {
    // 1. Retrieve the pending challenge (mark used atomically).
    let challenge = {
        let mut map = store.0.lock().expect("challenge store poisoned");
        let entry = map
            .get_mut(challenge_id)
            .ok_or_else(|| "no pending challenge with this id".to_string())?;

        if entry.is_expired() {
            map.remove(challenge_id);
            return Err("challenge has expired".to_string());
        }
        if entry.used {
            return Err("challenge already used".to_string());
        }
        entry.used = true;
        entry.clone()
    };

    // 2. Decode public key bytes (32 bytes).
    let pk_bytes: [u8; 32] = hex::decode(&challenge.public_key)
        .map_err(|_| "invalid public key hex".to_string())?
        .try_into()
        .map_err(|_| "public key must be 32 bytes".to_string())?;

    // 3. Decode signature bytes (64 bytes).
    let sig_bytes: [u8; 64] = hex::decode(signature_hex)
        .map_err(|_| "invalid signature hex".to_string())?
        .try_into()
        .map_err(|_| "signature must be 64 bytes".to_string())?;

    // 4. Verify.
    let verifying_key =
        VerifyingKey::from_bytes(&pk_bytes).map_err(|e| format!("invalid public key: {e}"))?;
    let signature = Signature::from_bytes(&sig_bytes);

    verifying_key
        .verify_strict(&challenge.nonce, &signature)
        .map_err(|e| format!("signature verification failed: {e}"))?;

    tracing::info!(public_key = %challenge.public_key, "challenge verified successfully");
    Ok(challenge.public_key)
}

/// Spawns a background task that evicts expired challenges every 60 seconds.
///
/// Prevents unbounded memory growth from challenges that were never completed.
pub fn spawn_challenge_cleanup(store: ChallengeStore) {
    tokio::spawn(async move {
        loop {
            tokio::time::sleep(Duration::from_secs(60)).await;
            let mut map = store.0.lock().expect("challenge store poisoned");
            map.retain(|_, c| !c.is_expired());
        }
    });
}

/// Spawns a background task that evicts expired sessions every 5 minutes.
///
/// Session TTL is read from `SESSION_TTL_SECS` (default: 14400 = 4 hours).
pub fn spawn_session_cleanup(sessions: SessionStore) {
    tokio::spawn(async move {
        let ttl = Duration::from_secs(
            std::env::var("SESSION_TTL_SECS")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(14400),
        );
        loop {
            tokio::time::sleep(Duration::from_secs(300)).await;
            let mut map = sessions.0.lock().expect("session store poisoned");
            map.retain(|_, entry| entry.created_at.elapsed() < ttl);
        }
    });
}
