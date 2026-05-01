import 'dart:developer' as dev;
import 'dart:typed_data';

/// BLOCKED(mls-phase-4): Full MLS RFC 9420 implementation via openmls FFI.
/// Currently this class is a stub that stores/forwards opaque blobs.
/// When openmls is integrated:
///   - generateKeyPackage() will produce a real MLS KeyPackage
///   - processCommit() will apply MLS tree updates atomically
///   - onEpochRotation() will clear plaintextCache for the group
abstract class MlsService {
  /// Generate an opaque MLS KeyPackage blob for [groupId].
  Future<Uint8List> generateKeyPackage(String groupId);

  /// Upload the [keyPackage] blob to the server for [groupId].
  Future<void> uploadKeyPackage(String groupId, Uint8List keyPackage);

  /// Apply an inbound MLS Commit message to advance the group epoch.
  ///
  /// Must be called atomically — a partial Commit application is a bug.
  Future<void> processCommit(String groupId, int epoch, Uint8List commitData);

  /// Called after a successful epoch transition for [groupId].
  ///
  /// Implementations must invalidate any cached plaintext that was encrypted
  /// under the previous epoch's key material.
  Future<void> onEpochRotation(String groupId, int newEpoch);

  /// Encrypt [plaintext] for the group identified by the opaque [groupState].
  ///
  /// Returns `(ciphertext, updatedState)`. The caller MUST persist [updatedState]
  /// — the MLS ratchet advances after every message.
  ///
  /// BLOCKED(frb-codegen): implemented in the `mls_bridge` Rust crate.
  Future<(Uint8List, Uint8List)> encryptMessage(
    Uint8List groupState,
    Uint8List plaintext,
  );

  /// Decrypt [ciphertext] using the group key encoded in [groupState].
  ///
  /// Returns `(plaintext, updatedState)`. The caller MUST persist [updatedState].
  ///
  /// BLOCKED(frb-codegen): implemented in the `mls_bridge` Rust crate.
  Future<(Uint8List, Uint8List)> decryptMessage(
    Uint8List groupState,
    Uint8List ciphertext,
  );
}

/// Stub implementation of [MlsService].
///
/// All methods are no-ops that emit a debug log. Replace with the real
/// openmls-backed implementation in Phase 4.
// BLOCKED(mls-phase-4): replace with openmls FFI implementation.
class StubMlsService implements MlsService {
  @override
  Future<Uint8List> generateKeyPackage(String groupId) async {
    dev.log(
      '[MLS stub] generateKeyPackage groupId=$groupId — returning empty blob',
      name: 'MlsService',
    );
    return Uint8List(0);
  }

  @override
  Future<void> uploadKeyPackage(String groupId, Uint8List keyPackage) async {
    dev.log(
      '[MLS stub] uploadKeyPackage groupId=$groupId len=${keyPackage.length}',
      name: 'MlsService',
    );
  }

  @override
  Future<void> processCommit(
    String groupId,
    int epoch,
    Uint8List commitData,
  ) async {
    dev.log(
      '[MLS stub] processCommit groupId=$groupId epoch=$epoch len=${commitData.length}',
      name: 'MlsService',
    );
    // BLOCKED(mls-phase-4): apply openmls Commit atomically here.
    //   The epoch transition must be atomic: Commit + Update/Remove together.
  }

  @override
  Future<void> onEpochRotation(String groupId, int newEpoch) async {
    dev.log(
      '[MLS stub] onEpochRotation groupId=$groupId newEpoch=$newEpoch',
      name: 'MlsService',
    );
    // BLOCKED(mls-phase-4): clear plaintextCache for all messages in this group epoch.
  }

  @override
  Future<(Uint8List, Uint8List)> encryptMessage(
    Uint8List groupState,
    Uint8List plaintext,
  ) async {
    dev.log(
      '[MLS stub] encryptMessage len=${plaintext.length} — no-op, returning plaintext',
      name: 'MlsService',
    );
    // BLOCKED(frb-codegen): no real MLS state — pass through unchanged.
    return (plaintext, groupState);
  }

  @override
  Future<(Uint8List, Uint8List)> decryptMessage(
    Uint8List groupState,
    Uint8List ciphertext,
  ) async {
    dev.log(
      '[MLS stub] decryptMessage len=${ciphertext.length} — no-op, returning ciphertext',
      name: 'MlsService',
    );
    // BLOCKED(frb-codegen): no real MLS state — pass through unchanged.
    return (ciphertext, groupState);
  }
}

/// Real MLS implementation backed by the Rust `mls_bridge` crate via
/// flutter_rust_bridge.
///
/// Each method calls the generated FFI binding.  The bridge serialises the
/// full openmls group state as a JSON blob; callers are responsible for
/// persisting that blob in SQLCipher between calls (see [BridgeState] in the
/// Rust source).
///
/// BLOCKED(frb-codegen): Run:
///   dart run flutter_rust_bridge_codegen generate
/// in the client/ directory to generate the Dart bindings, then replace the
/// `throw UnimplementedError(...)` bodies below with the real calls.
class RealMlsService implements MlsService {
  /// Serialised [BridgeState] returned by the Rust crate; stored in
  /// SQLCipher between calls.
  final Map<String, Uint8List> _groupStates = {}; // ignore: unused_field

  /// Hex-encoded Ed25519 identity public key for this device.
  final String identityKeyHex;

  RealMlsService({required this.identityKeyHex});

  @override
  Future<Uint8List> generateKeyPackage(String groupId) async {
    // BLOCKED(frb-codegen): Run: dart run flutter_rust_bridge_codegen generate
    // Then replace with:
    //   final stateBytes = await MlsBridgeImpl.generateKeyPackage(
    //     groupId: groupId,
    //     identityKeyHex: identityKeyHex,
    //   );
    //   _groupStates[groupId] = Uint8List.fromList(stateBytes);
    //   // Extract the public KeyPackage TLS bytes from the state JSON
    //   // for server upload (field: key_package_tls).
    //   return _extractKeyPackageTls(stateBytes);
    throw UnimplementedError(
      'Run flutter_rust_bridge_codegen generate first. '
      'See client/rust/mls_bridge/src/lib.rs for the Rust API.',
    );
  }

  @override
  Future<void> uploadKeyPackage(String groupId, Uint8List keyPackage) async {
    // BLOCKED(frb-codegen): HTTP POST to /mls/key-packages with keyPackage bytes.
    throw UnimplementedError('Run flutter_rust_bridge_codegen generate first.');
  }

  @override
  Future<void> processCommit(
    String groupId,
    int epoch,
    Uint8List commitData,
  ) async {
    // BLOCKED(frb-codegen): Run: dart run flutter_rust_bridge_codegen generate
    // Then replace with:
    //   final currentState = _groupStates[groupId]!;
    //   final updatedState = await MlsBridgeImpl.processCommit(
    //     groupState: currentState,
    //     commitBytes: commitData,
    //   );
    //   _groupStates[groupId] = Uint8List.fromList(updatedState);
    throw UnimplementedError('Run flutter_rust_bridge_codegen generate first.');
  }

  @override
  Future<void> onEpochRotation(String groupId, int newEpoch) async {
    // BLOCKED(frb-codegen): Run: dart run flutter_rust_bridge_codegen generate
    // Epoch rotation is handled automatically by processCommit via MLS.
    // This hook can be used to clear application-level plaintext caches.
    dev.log(
      '[MLS real] onEpochRotation groupId=$groupId newEpoch=$newEpoch',
      name: 'MlsService',
    );
  }

  @override
  Future<(Uint8List, Uint8List)> encryptMessage(
    Uint8List groupState,
    Uint8List plaintext,
  ) async {
    // BLOCKED(frb-codegen): Run: dart run flutter_rust_bridge_codegen generate
    // Then replace with:
    //   final result = await MlsBridgeImpl.encryptMessage(
    //     groupState: groupState,
    //     plaintext: plaintext,
    //   );
    //   return (Uint8List.fromList(result.$1), Uint8List.fromList(result.$2));
    throw UnimplementedError('Run flutter_rust_bridge_codegen generate first.');
  }

  @override
  Future<(Uint8List, Uint8List)> decryptMessage(
    Uint8List groupState,
    Uint8List ciphertext,
  ) async {
    // BLOCKED(frb-codegen): Run: dart run flutter_rust_bridge_codegen generate
    // Then replace with:
    //   final result = await MlsBridgeImpl.decryptMessage(
    //     groupState: groupState,
    //     ciphertext: ciphertext,
    //   );
    //   return (Uint8List.fromList(result.$1), Uint8List.fromList(result.$2));
    throw UnimplementedError('Run flutter_rust_bridge_codegen generate first.');
  }
}
