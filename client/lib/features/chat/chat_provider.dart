import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_config.dart';
import '../../core/crypto/dart_cryptography_service.dart';
import '../../core/crypto/mls_provider.dart';
import '../../core/crypto/mls_service.dart';
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
    required MlsService mlsService,
    String? currentUserId,
    Uint8List? encryptionPrivateKey,
  })  : _db = db,
        _wsClient = wsClient,
        _mlsService = mlsService,
        _currentUserId = currentUserId,
        _encryptionPrivateKey = encryptionPrivateKey;

  final AppDatabase _db;
  final WsClient _wsClient;
  final MlsService _mlsService;
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
      // BLOCKED(mls-phase-4): group message fan-out — encrypt once per recipient
      // when MLS group key management is implemented in Phase 4.
      // For now, fall through without encryption when no per-contact X25519 key
      // is available (e.g. group conversations, or contacts added before key exchange).
      payload = plaintextBytes;
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
  /// On decryption success: stores the plaintext bytes in [plaintextCache].
  /// On failure: stores [_kDecryptFailed] so the UI can show an error indicator.
  /// If the own private key is not yet loaded: stores null so the UI shows a
  /// generic encrypted-message indicator.
  Future<void> handleIncoming(Envelope envelope) async {
    final id = '${envelope.from}_${DateTime.now().microsecondsSinceEpoch}';

    Uint8List? plaintextCache;
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
  /// Calls [MlsService.processCommit] to apply the Commit blob, then
  /// [MlsService.onEpochRotation] to invalidate stale plaintext caches.
  Future<void> handleMlsCommit(
    String groupId,
    int epoch,
    Uint8List commitData,
  ) async {
    await _mlsService.processCommit(groupId, epoch, commitData);
    await _mlsService.onEpochRotation(groupId, epoch);
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
  final mlsService = ref.watch(mlsServiceProvider);
  final encPrivKey =
      ref.watch(authProvider.select((s) => s.encryptionPrivateKey));
  return _ChatService(
    db: db,
    wsClient: ws,
    currentUserId: userId,
    mlsService: mlsService,
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
