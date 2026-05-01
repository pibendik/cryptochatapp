import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../db/database_provider.dart';
import 'mls_provider.dart';
import 'mls_service.dart';

/// Orchestrates MLS group operations using the mls_bridge Rust crate (via
/// [MlsService]) and persists group state to drift via [AppDatabase].
///
/// The [AppDatabase.getMlsState] / [AppDatabase.saveMlsState] helpers store the
/// opaque `BridgeState` JSON blob produced by the Rust crate.  The Dart layer
/// never inspects the contents of that blob.
///
/// BLOCKED(frb-codegen): All methods that reach into [RealMlsService] will throw
/// [UnimplementedError] until `dart run flutter_rust_bridge_codegen generate` is
/// run in the `client/` directory.  The [StubMlsService] no-ops are used in the
/// meantime, so all fallback paths in chat_provider / forum_provider remain active.
class MlsGroupService {
  final MlsService _mls;
  final AppDatabase _db;

  MlsGroupService(this._mls, this._db);

  /// Encrypt [plaintext] for the group identified by [groupId] using the
  /// current MLS epoch key.
  ///
  /// Persists the updated group state after the ratchet advances.
  /// Throws [MlsStateNotReadyException] if no MLS state exists for [groupId]
  /// — the caller should fall back to ECIES or self-encrypt as appropriate.
  Future<Uint8List> encryptForGroup(String groupId, Uint8List plaintext) async {
    final stateRow = await _db.getMlsState(groupId);
    if (stateRow == null) throw MlsStateNotReadyException(groupId);

    final (ciphertext, newState) =
        await _mls.encryptMessage(stateRow.stateData, plaintext);
    await _db.saveMlsState(groupId, newState, stateRow.epoch);
    return ciphertext;
  }

  /// Decrypt [ciphertext] for [groupId] using the current MLS epoch key.
  ///
  /// Persists the updated group state after the ratchet advances.
  /// Throws [MlsStateNotReadyException] if no MLS state exists for [groupId].
  Future<Uint8List> decryptForGroup(String groupId, Uint8List ciphertext) async {
    final stateRow = await _db.getMlsState(groupId);
    if (stateRow == null) throw MlsStateNotReadyException(groupId);

    final (plaintext, newState) =
        await _mls.decryptMessage(stateRow.stateData, ciphertext);
    await _db.saveMlsState(groupId, newState, stateRow.epoch);
    return plaintext;
  }

  /// Process an incoming MLS Commit (epoch rotation) for [groupId].
  ///
  /// Delegates to [MlsService.processCommit] then stores the new [epoch] and
  /// clears the plaintext cache so stale content encrypted under the old epoch
  /// key is not displayed.
  ///
  /// If no MLS state is found for [groupId] the call is a safe no-op.
  Future<void> processCommit(
    String groupId,
    int epoch,
    Uint8List commitData,
  ) async {
    final stateRow = await _db.getMlsState(groupId);
    if (stateRow == null) return;

    // Apply the Commit via the MLS service (no-op for StubMlsService).
    await _mls.processCommit(groupId, epoch, commitData);
    // Persist the updated epoch number; state blob is updated by processCommit
    // once frb-codegen bridges the Rust return value.
    await _db.saveMlsState(groupId, stateRow.stateData, epoch);
    // Invalidate cached plaintexts — old epoch key can no longer be trusted.
    await _db.clearPlaintextCacheForGroup(groupId);
  }
}

/// Thrown by [MlsGroupService] when no MLS group state has been initialised
/// for the requested [groupId].
///
/// Callers should catch this and fall back to the previous encryption scheme
/// (ECIES fan-out for group messages, self-encrypt for forum titles) until MLS
/// setup is complete.
class MlsStateNotReadyException implements Exception {
  final String groupId;
  const MlsStateNotReadyException(this.groupId);

  @override
  String toString() =>
      'MLS state not initialised for group $groupId. '
      'Run flutter_rust_bridge_codegen generate and perform group setup.';
}

/// Provides the active [MlsGroupService] instance.
///
/// Depends on [mlsServiceProvider] and [appDatabaseProvider]; re-created
/// automatically when either dependency changes.
final mlsGroupServiceProvider = Provider<MlsGroupService>((ref) {
  return MlsGroupService(
    ref.watch(mlsServiceProvider),
    ref.watch(appDatabaseProvider),
  );
});
