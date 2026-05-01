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
}
