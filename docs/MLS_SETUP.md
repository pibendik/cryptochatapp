# MLS Client Setup

This document explains how to build the `mls_bridge` Rust native library and wire it into the Flutter app.

## Architecture

```
Flutter (Dart) ──── flutter_rust_bridge FFI ──── mls_bridge (Rust cdylib)
                                                       │
                                              openmls 0.8.1 (RFC 9420)
                                              openmls_rust_crypto 0.5
```

All MLS group-state is serialised as a JSON `BridgeState` blob and stored by the Dart layer in SQLCipher between calls. The Rust crate is stateless.

## Prerequisites

```sh
# Rust toolchain (stable)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Flutter SDK — https://docs.flutter.dev/get-started/install

# flutter_rust_bridge CLI
cargo install flutter_rust_bridge_codegen

# Platform cross-compile targets (add as needed)
rustup target add aarch64-linux-android    # Android arm64
rustup target add x86_64-linux-android     # Android x86_64
rustup target add aarch64-apple-ios        # iOS
rustup target add x86_64-apple-darwin      # macOS x86
rustup target add aarch64-apple-darwin     # macOS arm64 (Apple Silicon)
```

## Step 1 — Verify the Rust crate compiles

```sh
cd client/rust/mls_bridge
cargo check
# Expected: no errors, a few flutter_rust_bridge macro warnings
```

## Step 2 — Run flutter_rust_bridge codegen

```sh
cd client
dart run flutter_rust_bridge_codegen generate
```

This generates:
- `lib/src/rust/frb_generated.dart` — Dart FFI bindings
- `lib/src/rust/api/` — Dart wrapper classes

## Step 3 — Build the native library

### Linux / macOS desktop

```sh
cd client/rust/mls_bridge
cargo build --release
# Output: target/release/libmls_bridge.so  (Linux)
#         target/release/libmls_bridge.dylib  (macOS)
```

### Android

```sh
cargo ndk -t armeabi-v7a -t arm64-v8a -t x86_64 \
    -o ../../../client/android/app/src/main/jniLibs \
    build --release
```

### iOS

```sh
cargo lipo --release
# Copy universal lib to client/ios/
```

### Web (WASM)

flutter_rust_bridge v2 supports WASM targets. See [frb WASM docs](https://cjycode.com/flutter_rust_bridge/integrate/js_bridge.html) for setup.

## Step 4 — Switch from StubMlsService to RealMlsService

In `client/lib/core/crypto/mls_provider.dart`:

```dart
// Change this line:
final mlsServiceProvider = Provider<MlsService>((ref) => StubMlsService());

// To:
final mlsServiceProvider = Provider<MlsService>((ref) =>
    RealMlsService(identityKeyHex: ref.read(keychainProvider).identityPublicKeyHex));
```

## State serialisation

`generate_key_package` and `create_group` return a JSON `BridgeState` blob:

```json
{
  "storage_values": { "<hex-key>": "<hex-value>", ... },
  "group_id_bytes": [97, 98, 99],
  "signing_public_key": [1, 2, 3, ...],
  "key_package_tls": [1, 2, 3, ...]   // only set by generate_key_package
}
```

- `storage_values` — the full `openmls_memory_storage::MemoryStorage` (group tree, epoch secrets, etc.)
- `key_package_tls` — TLS-serialised public `KeyPackage` to POST to `/mls/key-packages`
- Persist the full blob in SQLCipher; pass it back on every subsequent call

## API summary

| Rust function | Called when |
|---|---|
| `generate_key_package(group_id, identity_key_hex)` | Device registration / key refresh |
| `create_group(group_id, identity_key_hex)` | Group admin bootstrapping a new group |
| `process_welcome(welcome_bytes, key_package_state)` | Joining a group via Welcome |
| `process_commit(group_state, commit_bytes)` | Member add/remove/update received |
| `encrypt_message(group_state, plaintext)` | Sending a message |
| `decrypt_message(group_state, ciphertext)` | Receiving a message |
