//! MLS client-side state machine bridge for flutter_rust_bridge.
//!
//! Implements the RFC 9420 MLS group state machine on the client.  The server
//! is a dumb Delivery Service that stores/forwards opaque blobs; all real MLS
//! logic lives here.
//!
//! ## State serialisation model
//!
//! Each function takes and returns a `group_state: Vec<u8>` parameter.  This
//! blob is a JSON-encoded [`BridgeState`] and is stored by the Dart layer in
//! SQLCipher between calls.  It contains the full `openmls_memory_storage`
//! key-value map plus metadata (group ID, signing public key).
//!
//! ## flutter_rust_bridge codegen
//!
//! The `#[frb]` attributes mark functions for Dart binding generation.  Run:
//!
//! ```sh
//! dart run flutter_rust_bridge_codegen generate
//! ```
//!
//! from the `client/` directory after installing `flutter_rust_bridge_codegen`.
//!
//! // BLOCKED(frb-codegen): generated bindings not yet present — cargo check
//! // compiles this crate standalone; Flutter integration requires codegen.

use std::collections::HashMap;

use flutter_rust_bridge::frb;
use openmls::prelude::*;
use openmls_basic_credential::SignatureKeyPair;
use openmls_rust_crypto::OpenMlsRustCrypto;
use serde::{Deserialize, Serialize};
use tls_codec::{Deserialize as TlsDeserialize, Serialize as TlsSerialize};

// ---------------------------------------------------------------------------
// Ciphersuite used throughout this crate
// ---------------------------------------------------------------------------

const CIPHERSUITE: Ciphersuite = Ciphersuite::MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519;

// ---------------------------------------------------------------------------
// Serialisable state snapshot (persisted by the Dart layer in SQLCipher)
// ---------------------------------------------------------------------------

/// Serialisable snapshot of everything the bridge needs to resume an MLS group
/// operation.  The Dart layer stores this in SQLCipher between calls.
#[derive(Serialize, Deserialize)]
struct BridgeState {
    /// All key-value pairs from `MemoryStorage` (opaque bytes).
    storage_values: HashMap<Vec<u8>, Vec<u8>>,
    /// GroupId bytes so we can load the group from storage.
    group_id_bytes: Vec<u8>,
    /// Public part of the Ed25519 signing key (needed to look up the private key in storage).
    signing_public_key: Vec<u8>,
    /// TLS-serialised public KeyPackage — present only after `generate_key_package`.
    #[serde(default)]
    key_package_tls: Vec<u8>,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Serialise a `BridgeState` to bytes.
fn state_to_bytes(state: &BridgeState) -> Result<Vec<u8>, String> {
    serde_json::to_vec(state).map_err(|e| format!("Failed to serialise bridge state: {e}"))
}

/// Deserialise a `BridgeState` from bytes.
fn state_from_bytes(bytes: &[u8]) -> Result<BridgeState, String> {
    serde_json::from_slice(bytes).map_err(|e| format!("Failed to deserialise bridge state: {e}"))
}

/// Build an `OpenMlsRustCrypto` provider pre-loaded with the given storage values.
///
/// `OpenMlsRustCrypto` exposes its internal `MemoryStorage` via
/// `provider.storage()`, which has a `pub values: RwLock<HashMap<…>>` field.
/// We reconstruct it by overwriting those values in a default-constructed
/// provider.
fn provider_from_state(state: &BridgeState) -> OpenMlsRustCrypto {
    let provider = OpenMlsRustCrypto::default();
    *provider.storage().values.write().unwrap() = state.storage_values.clone();
    provider
}

/// Dump provider storage values into a `BridgeState`.
fn state_from_provider(
    provider: &OpenMlsRustCrypto,
    group_id_bytes: Vec<u8>,
    signing_public_key: Vec<u8>,
    key_package_tls: Vec<u8>,
) -> BridgeState {
    BridgeState {
        storage_values: provider.storage().values.read().unwrap().clone(),
        group_id_bytes,
        signing_public_key,
        key_package_tls,
    }
}

// ---------------------------------------------------------------------------
// Public API (exported to Dart via flutter_rust_bridge codegen)
// ---------------------------------------------------------------------------

/// Generate a new MLS `KeyPackage` for this device.
///
/// Returns a JSON-encoded [`BridgeState`] blob.  The Dart layer must:
/// 1. Parse the blob and extract `key_package_tls` (hex or base64) to upload
///    to the server.
/// 2. Persist the full blob in SQLCipher for later use with
///    [`process_welcome`].
///
/// `identity_key_hex` — hex-encoded Ed25519 public key that identifies this
/// device (from the OS Keychain).  It becomes the MLS `BasicCredential`
/// identity.
#[frb]
pub fn generate_key_package(
    group_id: String,
    identity_key_hex: String,
) -> Result<Vec<u8>, String> {
    let provider = OpenMlsRustCrypto::default();

    let identity =
        hex::decode(&identity_key_hex).map_err(|e| format!("Bad identity hex: {e}"))?;
    let credential = BasicCredential::new(identity);
    let sig_keypair = SignatureKeyPair::new(SignatureScheme::ED25519)
        .map_err(|e| format!("Failed to generate signing key pair: {e}"))?;

    // Persist signing key in provider storage so it can be looked up later.
    sig_keypair
        .store(provider.storage())
        .map_err(|e| format!("Failed to store signing key pair: {e}"))?;

    let credential_with_key = CredentialWithKey {
        credential: credential.into(),
        signature_key: sig_keypair.public().into(),
    };

    let bundle = KeyPackage::builder()
        .build(CIPHERSUITE, &provider, &sig_keypair, credential_with_key)
        .map_err(|e| format!("Failed to build KeyPackage: {e}"))?;

    // TLS-serialise the public KeyPackage for server upload.
    let kp_tls = bundle
        .key_package()
        .tls_serialize_detached()
        .map_err(|e| format!("Failed to TLS-serialise KeyPackage: {e}"))?;

    let state = state_from_provider(
        &provider,
        group_id.into_bytes(),
        sig_keypair.public().to_vec(),
        kp_tls,
    );
    state_to_bytes(&state)
}

/// Create a new MLS group (called by the group admin after the key-signing
/// ceremony).
///
/// Returns a serialised [`BridgeState`] representing the initial group state.
/// The Dart layer stores this in SQLCipher.
#[frb]
pub fn create_group(group_id: String, identity_key_hex: String) -> Result<Vec<u8>, String> {
    let provider = OpenMlsRustCrypto::default();

    let identity =
        hex::decode(&identity_key_hex).map_err(|e| format!("Bad identity hex: {e}"))?;
    let credential = BasicCredential::new(identity);
    let sig_keypair = SignatureKeyPair::new(SignatureScheme::ED25519)
        .map_err(|e| format!("Failed to generate signing key pair: {e}"))?;

    sig_keypair
        .store(provider.storage())
        .map_err(|e| format!("Failed to store signing key pair: {e}"))?;

    let credential_with_key = CredentialWithKey {
        credential: credential.into(),
        signature_key: sig_keypair.public().into(),
    };

    let config = MlsGroupCreateConfig::builder()
        .use_ratchet_tree_extension(true)
        .build();

    let group_id_bytes = group_id.into_bytes();

    MlsGroup::new_with_group_id(
        &provider,
        &sig_keypair,
        &config,
        GroupId::from_slice(&group_id_bytes),
        credential_with_key,
    )
    .map_err(|e| format!("Failed to create MLS group: {e}"))?;

    let state = state_from_provider(
        &provider,
        group_id_bytes,
        sig_keypair.public().to_vec(),
        Vec::new(),
    );
    state_to_bytes(&state)
}

/// Process a `Welcome` message (join an existing group).
///
/// `welcome_bytes` — TLS-serialised `Welcome` message received from the DS.
/// `key_package_state` — the [`BridgeState`] blob returned by
/// [`generate_key_package`] (contains the private key package material).
///
/// Returns a serialised [`BridgeState`] for the joined group.
#[frb]
pub fn process_welcome(
    welcome_bytes: Vec<u8>,
    key_package_bytes: Vec<u8>,
) -> Result<Vec<u8>, String> {
    // Restore provider from the key-package generation state (which has the
    // private init key needed to decrypt the Welcome).
    let kp_state = state_from_bytes(&key_package_bytes)?;
    let provider = provider_from_state(&kp_state);

    let mut welcome_ref: &[u8] = &welcome_bytes;
    let mls_welcome = MlsMessageIn::tls_deserialize(&mut welcome_ref)
        .map_err(|e| format!("Failed to deserialise Welcome: {e}"))?;

    let welcome = match mls_welcome.extract() {
        MlsMessageBodyIn::Welcome(w) => w,
        other => return Err(format!("Expected Welcome, got {other:?}")),
    };

    let join_config = MlsGroupJoinConfig::builder()
        .use_ratchet_tree_extension(true)
        .build();

    // In openmls 0.8 the two-step join API is: StagedWelcome → MlsGroup.
    // The ratchet tree is included in the Welcome extension (enabled above).
    let group = StagedWelcome::new_from_welcome(&provider, &join_config, welcome, None)
        .map_err(|e| format!("Failed to stage Welcome: {e}"))?
        .into_group(&provider)
        .map_err(|e| format!("Failed to finalise Welcome into group: {e}"))?;

    let group_id_bytes = group.group_id().as_slice().to_vec();
    let signing_pub = kp_state.signing_public_key.clone();

    let state = state_from_provider(&provider, group_id_bytes, signing_pub, Vec::new());
    state_to_bytes(&state)
}

/// Process a `Commit` message (member add/remove/update, epoch rotation).
///
/// Atomically advances the group epoch.  Per the project conventions, this
/// must never be applied partially.
///
/// Returns the updated serialised group state.
#[frb]
pub fn process_commit(
    group_state: Vec<u8>,
    commit_bytes: Vec<u8>,
) -> Result<Vec<u8>, String> {
    let state = state_from_bytes(&group_state)?;
    let provider = provider_from_state(&state);

    let group_id = GroupId::from_slice(&state.group_id_bytes);
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|e| format!("Failed to load MLS group from storage: {e}"))?
        .ok_or("MLS group not found in storage")?;

    let mut msg_ref: &[u8] = &commit_bytes;
    let mls_msg = MlsMessageIn::tls_deserialize(&mut msg_ref)
        .map_err(|e| format!("Failed to deserialise Commit message: {e}"))?;

    let protocol_msg: ProtocolMessage = mls_msg
        .try_into_protocol_message()
        .map_err(|e| format!("Expected protocol message: {e}"))?;

    let processed = group
        .process_message(&provider, protocol_msg)
        .map_err(|e| format!("Failed to process Commit: {e}"))?;

    // Atomically merge the staged commit to advance the epoch.
    // BLOCKED(mls-phase-4): inspect staged commit for member add/remove before merging.
    match processed.into_content() {
        ProcessedMessageContent::StagedCommitMessage(staged_commit) => {
            group
                .merge_staged_commit(&provider, *staged_commit)
                .map_err(|e| format!("Failed to merge Commit: {e}"))?;
        }
        other => return Err(format!("Expected StagedCommit, got {other:?}")),
    }

    let updated_state = state_from_provider(
        &provider,
        state.group_id_bytes,
        state.signing_public_key,
        Vec::new(),
    );
    state_to_bytes(&updated_state)
}

/// Encrypt an application message using the current MLS epoch key.
///
/// Returns `(ciphertext_bytes, updated_group_state)`.  The `Double Ratchet`
/// inside MLS advances after each message, so the caller **must** persist the
/// updated state.
#[frb]
pub fn encrypt_message(
    group_state: Vec<u8>,
    plaintext: Vec<u8>,
) -> Result<(Vec<u8>, Vec<u8>), String> {
    let state = state_from_bytes(&group_state)?;
    let provider = provider_from_state(&state);

    let group_id = GroupId::from_slice(&state.group_id_bytes);
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|e| format!("Failed to load MLS group: {e}"))?
        .ok_or("MLS group not found in storage")?;

    // Reconstruct the signing key from storage using the stored public key.
    let sig_keypair = SignatureKeyPair::read(
        provider.storage(),
        &state.signing_public_key,
        CIPHERSUITE.signature_algorithm(),
    )
    .ok_or("Signing key not found in storage — was it stored with generate_key_package or create_group?")?;

    let mls_msg = group
        .create_message(&provider, &sig_keypair, &plaintext)
        .map_err(|e| format!("Failed to encrypt message: {e}"))?;

    let ciphertext = mls_msg
        .tls_serialize_detached()
        .map_err(|e| format!("Failed to serialise ciphertext: {e}"))?;

    let updated_state = state_from_provider(
        &provider,
        state.group_id_bytes,
        state.signing_public_key,
        Vec::new(),
    );
    let updated_state_bytes = state_to_bytes(&updated_state)?;

    Ok((ciphertext, updated_state_bytes))
}

/// Decrypt an application message.
///
/// Returns `(plaintext_bytes, updated_group_state)`.  The caller must persist
/// the updated state — the ratchet advances on every message.
#[frb]
pub fn decrypt_message(
    group_state: Vec<u8>,
    ciphertext: Vec<u8>,
) -> Result<(Vec<u8>, Vec<u8>), String> {
    let state = state_from_bytes(&group_state)?;
    let provider = provider_from_state(&state);

    let group_id = GroupId::from_slice(&state.group_id_bytes);
    let mut group = MlsGroup::load(provider.storage(), &group_id)
        .map_err(|e| format!("Failed to load MLS group: {e}"))?
        .ok_or("MLS group not found in storage")?;

    let mut msg_ref: &[u8] = &ciphertext;
    let mls_msg = MlsMessageIn::tls_deserialize(&mut msg_ref)
        .map_err(|e| format!("Failed to deserialise ciphertext: {e}"))?;

    let protocol_msg: ProtocolMessage = mls_msg
        .try_into_protocol_message()
        .map_err(|e| format!("Expected protocol message: {e}"))?;

    let processed = group
        .process_message(&provider, protocol_msg)
        .map_err(|e| format!("Failed to decrypt message: {e}"))?;

    let plaintext = match processed.into_content() {
        ProcessedMessageContent::ApplicationMessage(app_msg) => app_msg.into_bytes(),
        other => {
            return Err(format!(
                    "Expected ApplicationMessage, got {other:?}"
                ))
        }
    };

    let updated_state = state_from_provider(
        &provider,
        state.group_id_bytes,
        state.signing_public_key,
        Vec::new(),
    );
    let updated_state_bytes = state_to_bytes(&updated_state)?;

    Ok((plaintext, updated_state_bytes))
}
