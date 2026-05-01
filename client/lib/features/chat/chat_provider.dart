import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_config.dart';
import '../../core/crypto/dart_cryptography_service.dart';
import '../../core/crypto/mls_group_service.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/models/envelope.dart';
import '../../core/models/message.dart';
import '../../core/network/ws_client.dart';
import '../auth/auth_provider.dart';

part 'chat_provider.g.dart';

// ── Isolate-safe encrypt/decrypt helpers ──────────────────────────────────
// Top-level functions required by compute() — must be outside any class.
// DartCryptographyService is pure Dart (no platform channels), so it is
// safe to instantiate inside a background isolate.

Future<Uint8List> _encryptMessage(
  ({Uint8List plaintext, Uint8List recipientKey}) args,
) async {
  final crypto = DartCryptographyService();
  return crypto.encrypt(args.plaintext, args.recipientKey);
}

Future<Uint8List?> _decryptMessage(
  ({Uint8List ciphertext, Uint8List senderKey}) args,
) async {
  try {
    final crypto = DartCryptographyService();
    return await crypto.decrypt(args.ciphertext, args.senderKey);
  } catch (_) {
    return null;
  }
}

/// Sentinel stored in [MessagesTable.plaintextCache] when decryption fails.
/// Starts with a null byte so it cannot collide with valid UTF-8 message text.
const _kDecryptFailed = '\x00DECRYPT_FAILED';

// ── WsClient provider ──────────────────────────────────────────────────────

@riverpod
WsClient wsClient(Ref ref) {
  final client = WsClient(
    uri: Uri.parse(ref.watch(appConfigProvider).wsUrl),
    secureStorage: ref.read(secureStorageProvider),
    db: ref.read(appDatabaseProvider),
  );
  ref.onDispose(client.disconnect);
  return client;
}

// ── Chat service ───────────────────────────────────────────────────────────

class _ChatService {
  _ChatService({
    required AppDatabase db,
    required WsClient wsClient,
    required MlsGroupService mlsGroupService,
    String? currentUserId,
    Uint8List? encryptionPrivateKey,
  })  : _db = db,
        _wsClient = wsClient,
        _mlsGroupService = mlsGroupService,
        _currentUserId = currentUserId,
        _encryptionPrivateKey = encryptionPrivateKey;

  final AppDatabase _db;
  final WsClient _wsClient;
  final MlsGroupService _mlsGroupService;
  final String? _currentUserId;
  final Uint8List? _encryptionPrivateKey;

  /// Reactive stream of messages for [conversationId], ordered oldest-first.
  Stream<List<MessagesTableData>> watchMessages(String conversationId) =>
      _db.watchConversation(conversationId);

  /// Encrypt [plaintext] for [toId] and enqueue for delivery.
  ///
  /// Looks up the recipient's X25519 encryption public key in [ContactsTable].
  /// If found, encrypts with ECIES (X25519 + HKDF + ChaCha20-Poly1305) before
  /// sending. Own sent messages are always stored with [plaintextCache] populated.
  Future<void> sendMessage(String toId, String plaintext) async {
    final id =
        'out_${_currentUserId ?? 'anon'}_${DateTime.now().microsecondsSinceEpoch}';
    final plaintextBytes = Uint8List.fromList(utf8.encode(plaintext));

    Uint8List payload;
    final contact = await _db.getContactById(toId);
    if (contact != null && contact.encryptionPublicKey.isNotEmpty) {
      // 1:1 DM — encrypt with the recipient's X25519 key (ECIES).
      try {
        payload = await compute(
          _encryptMessage,
          (plaintext: plaintextBytes, recipientKey: contact.encryptionPublicKey),
        );
      } catch (_) {
        // Encryption failed — send unencrypted as last resort so the message
        // is not silently dropped. This should not occur in normal operation.
        payload = plaintextBytes;
      }
    } else {
      // Group message — encrypt with the MLS epoch key.
      try {
        payload = await _mlsGroupService.encryptForGroup(toId, plaintextBytes);
      } on MlsStateNotReadyException {
        // FALLBACK(mls-not-ready): MLS group not yet initialised — send
        // unencrypted until key setup is complete.
        payload = plaintextBytes;
      }
    }

    await _db.insertMessage(MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(toId),
      senderId: Value(_currentUserId ?? ''),
      payload: Value(payload),
      // Own sent messages are always cached — no need to decrypt locally.
      plaintextCache: Value(plaintextBytes),
      createdAt: Value(DateTime.now()),
      isDelivered: const Value(false),
    ));
    await _wsClient.enqueue(toId, payload);
  }

  /// Decrypt an inbound [envelope] and persist to the local database.
  ///
  /// For group messages (MLS state available for `envelope.to`): decrypts with
  /// the MLS epoch key via [MlsGroupService].
  /// For 1:1 DMs (no MLS state): falls back to ECIES using the local private key.
  /// On decryption failure: stores [_kDecryptFailed] sentinel in plaintextCache.
  Future<void> handleIncoming(Envelope envelope) async {
    final id = '${envelope.from}_${DateTime.now().microsecondsSinceEpoch}';

    Uint8List? plaintextCache;

    // Try MLS group decrypt first.  getMlsState returns null for 1:1 DM
    // conversation IDs (no group state stored), so this throws
    // MlsStateNotReadyException for those — cleanly falling back to ECIES.
    try {
      plaintextCache =
          await _mlsGroupService.decryptForGroup(envelope.to, envelope.payload);
    } on MlsStateNotReadyException {
      // FALLBACK(mls-not-ready): no MLS state for this conversation — try
      // ECIES 1:1 decrypt with the local private key.
      if (_encryptionPrivateKey != null) {
        final decrypted = await compute(
          _decryptMessage,
          (ciphertext: envelope.payload, senderKey: _encryptionPrivateKey!),
        );
        plaintextCache = decrypted ??
            Uint8List.fromList(utf8.encode(_kDecryptFailed));
      }
      // If _encryptionPrivateKey is null, plaintextCache stays null →
      // UI shows "🔒 Encrypted message".
    } catch (_) {
      plaintextCache = Uint8List.fromList(utf8.encode(_kDecryptFailed));
    }

    await _db.insertMessage(MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(envelope.to),
      senderId: Value(envelope.from),
      payload: Value(envelope.payload),
      plaintextCache: Value(plaintextCache),
      createdAt: Value(DateTime.now()),
      isDelivered: const Value(true),
    ));
  }

  /// Handle an inbound `mls_commit` WebSocket event for [groupId].
  ///
  /// Delegates to [MlsGroupService.processCommit] which applies the Commit,
  /// persists the new epoch, and invalidates stale plaintext caches.
  Future<void> handleMlsCommit(
    String groupId,
    int epoch,
    Uint8List commitData,
  ) async {
    await _mlsGroupService.processCommit(groupId, epoch, commitData);
  }
}

/// Watches the most recent message for [conversationId].
///
/// Emits `null` when no messages exist yet for that conversation.
final lastMessageProvider =
    StreamProvider.autoDispose.family<MessagesTableData?, String>(
  (ref, conversationId) {
    final db = ref.watch(appDatabaseProvider);
    return db.watchLastMessage(conversationId);
  },
);

/// Provides access to [_ChatService] for sending messages and watching streams.
final chatProvider = Provider.autoDispose<_ChatService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final ws = ref.watch(wsClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.userId));
  final mlsGroupService = ref.watch(mlsGroupServiceProvider);
  final encPrivKey =
      ref.watch(authProvider.select((s) => s.encryptionPrivateKey));
  return _ChatService(
    db: db,
    wsClient: ws,
    currentUserId: userId,
    mlsGroupService: mlsGroupService,
    encryptionPrivateKey: encPrivKey,
  );
});

// ── Legacy per-chat notifier (kept for generated code compat) ──────────────

@riverpod
class ChatMessages extends _$ChatMessages {
  @override
  List<Message> build(String chatId) {
    // Route inbound WS envelopes for this conversation to the chat service.
    final ws = ref.watch(wsClientProvider);
    ws.onEnvelope = (envelope) {
      if (envelope.to == chatId) {
        ref.read(chatProvider).handleIncoming(envelope);
      }
    };

    // Route inbound MLS Commit events to the MLS service.
    // When a `mls_commit` event arrives the chat service calls processCommit
    // and onEpochRotation so stale plaintext caches are invalidated.
    final sub = ws.rawMessages.listen((map) {
      if (map['type'] == 'mls_commit') {
        final groupId = map['groupId'] as String?;
        final epoch = map['epoch'];
        final commitDataB64 = map['commitData'] as String?;
        if (groupId == null || epoch == null || commitDataB64 == null) return;
        final epochInt = epoch is int ? epoch : int.tryParse(epoch.toString()) ?? 0;
        final commitData = base64Decode(commitDataB64);
        ref.read(chatProvider).handleMlsCommit(groupId, epochInt, commitData);
      }
    });
    ref.onDispose(sub.cancel);

    return [];
  }

  /// Forward an outbound plaintext message through the chat service.
  Future<void> sendMessage(String toId, String plaintext) async {
    await ref.read(chatProvider).sendMessage(toId, plaintext);
  }
}
