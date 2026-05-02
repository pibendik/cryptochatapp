//! MLS Delivery Service helper.
//!
//! The server is a **dumb-pipe Delivery Service** per RFC 9420 §4.  It never
//! holds private keys, never joins a group, and never applies MLS state.
//!
//! This module provides only the two operations the server legitimately needs:
//!   1. `validate_key_package` — parse & signature-verify a client-submitted
//!      KeyPackage blob before persisting it.
//!   2. `classify_message` — detect the MLS message type so the relay can
//!      make correct routing decisions (Welcome → new member only;
//!      PublicMessage / PrivateMessage → all current group members).
//!
//! // BLOCKED(mls-client-phase-4): client-side MLS state machine — the server
//! // intentionally does NOT apply Commit messages, validate Commit contents,
//! // maintain MLS group state, or decrypt PrivateMessage payloads.

use openmls::prelude::{
    KeyPackageIn, KeyPackageRef, MlsMessageBodyIn, MlsMessageIn, ProtocolVersion,
};
use openmls_rust_crypto::OpenMlsRustCrypto;
use openmls_traits::OpenMlsProvider;
use tls_codec::Deserialize as TlsDeserialize;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

pub struct MlsDeliveryService;

impl MlsDeliveryService {
    /// Validates a KeyPackage blob submitted by a client.
    ///
    /// Performs:
    /// - TLS deserialisation
    /// - Leaf-node signature verification (Ed25519 / P-256 depending on
    ///   ciphersuite)
    /// - Lifetime check (not-before / not-after)
    ///
    /// Returns the identity (hex-encoded signature public key from the leaf
    /// node) and a [`KeyPackageRef`] on success, or a [`MlsDeliveryError`] on
    /// failure.
    pub fn validate_key_package(data: &[u8]) -> Result<ValidatedKeyPackage, MlsDeliveryError> {
        let provider = OpenMlsRustCrypto::default();

        let mut bytes: &[u8] = data;
        let kp_in = KeyPackageIn::tls_deserialize(&mut bytes)
            .map_err(|_| MlsDeliveryError::MalformedKeyPackage)?;

        // Verify the leaf-node signature and protocol version.
        let kp = kp_in
            .validate(provider.crypto(), ProtocolVersion::Mls10)
            .map_err(|_| MlsDeliveryError::InvalidSignature)?;

        // Check not-before / not-after lifetime bounds.
        if !kp.life_time().is_valid() {
            return Err(MlsDeliveryError::ExpiredKeyPackage);
        }

        let identity = hex::encode(kp.leaf_node().signature_key().as_slice());
        let kp_ref = kp
            .hash_ref(provider.crypto())
            .map_err(|_| MlsDeliveryError::HashError)?;

        Ok(ValidatedKeyPackage { identity, kp_ref })
    }

    /// Classifies an MLS message blob for routing.
    ///
    /// Routing rules:
    /// - `Welcome`        → route only to the new-member recipient(s) listed in
    ///                      the encrypted group secrets.
    ///   // TODO(mls-welcome-routing): extract KeyPackageRef targets from the
    ///   // Welcome and route per-recipient once the key-package directory is
    ///   // queryable by ref.
    /// - `PublicMessage`  → broadcast to all current group members.
    /// - `PrivateMessage` → broadcast to all current group members.
    /// - `Unknown`        → malformed or unsupported blob; caller should reject.
    ///
    /// // BLOCKED(mls-client-phase-4): client-side MLS state machine — the
    /// // server intentionally does not validate Commit contents or decrypt
    /// // PrivateMessage payloads.
    pub fn classify_message(data: &[u8]) -> MlsMessageType {
        let mut bytes: &[u8] = data;
        match MlsMessageIn::tls_deserialize(&mut bytes) {
            Ok(msg) => match msg.extract() {
                MlsMessageBodyIn::Welcome(_) => MlsMessageType::Welcome,
                MlsMessageBodyIn::PublicMessage(_) => MlsMessageType::PublicMessage,
                MlsMessageBodyIn::PrivateMessage(_) => MlsMessageType::PrivateMessage,
                // GroupInfo and KeyPackage blobs are not routed via the commit
                // path — treat them as unknown here.
                _ => MlsMessageType::Unknown,
            },
            Err(_) => MlsMessageType::Unknown,
        }
    }
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A KeyPackage that has passed full validation (signature + lifetime).
pub struct ValidatedKeyPackage {
    /// Hex-encoded signature public key from the leaf node.
    /// Used by handlers to verify the submitter matches the KeyPackage identity.
    pub identity: String,
    /// Hash-based reference to this KeyPackage (used for Welcome routing).
    /// Used when sending MLS Welcome messages to a specific new member.
    pub kp_ref: KeyPackageRef,
}

/// Message type classification returned by [`MlsDeliveryService::classify_message`].
#[derive(Debug, PartialEq, Eq)]
pub enum MlsMessageType {
    /// Welcome — route only to the intended new member(s).
    Welcome,
    /// PublicMessage (plaintext Proposal/Commit) — broadcast to the group.
    PublicMessage,
    /// PrivateMessage (ciphertext App/Proposal/Commit) — broadcast to the group.
    PrivateMessage,
    /// Unrecognised or malformed blob; the caller should reject with 400.
    Unknown,
}

/// Errors produced by [`MlsDeliveryService`].
#[derive(Debug, thiserror::Error)]
pub enum MlsDeliveryError {
    #[error("malformed key package: TLS deserialisation failed")]
    MalformedKeyPackage,
    #[error("invalid key package: signature verification failed")]
    InvalidSignature,
    #[error("key package lifetime has expired or is not yet valid")]
    ExpiredKeyPackage,
    #[error("failed to compute key package hash reference")]
    HashError,
}
