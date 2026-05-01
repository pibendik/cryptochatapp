import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/models/envelope.dart';
import '../../core/models/message.dart';
import '../../core/network/ws_client.dart';
import '../auth/auth_provider.dart';

part 'chat_provider.g.dart';

// ── WsClient provider ──────────────────────────────────────────────────────

@riverpod
WsClient wsClient(Ref ref) {
  final client = WsClient(
    uri: Uri.parse(
      // TODO: read from config / environment
      const String.fromEnvironment(
          'WS_URL', defaultValue: 'wss://localhost:8080/ws'),
    ),
    secureStorage: ref.read(secureStorageProvider),
  );
  ref.onDispose(client.disconnect);
  return client;
}

// ── Chat service ───────────────────────────────────────────────────────────

class _ChatService {
  _ChatService({
    required AppDatabase db,
    required WsClient wsClient,
    String? currentUserId,
  })  : _db = db,
        _wsClient = wsClient,
        _currentUserId = currentUserId;

  final AppDatabase _db;
  final WsClient _wsClient;
  final String? _currentUserId;

  /// Reactive stream of messages for [conversationId], ordered oldest-first.
  Stream<List<MessagesTableData>> watchMessages(String conversationId) =>
      _db.watchConversation(conversationId);

  /// Insert a pending outbound message then enqueue it on the WS transport.
  Future<void> sendMessage(String toId, Uint8List encryptedPayload) async {
    final id =
        'out_${_currentUserId ?? 'anon'}_${DateTime.now().microsecondsSinceEpoch}';
    await _db.insertMessage(MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(toId),
      senderId: Value(_currentUserId ?? ''),
      payload: Value(encryptedPayload),
      createdAt: Value(DateTime.now()),
      isDelivered: const Value(false),
    ));
    _wsClient.enqueue(toId, encryptedPayload);
  }

  /// Handle an inbound envelope: stub-decrypt and persist as delivered.
  Future<void> handleIncoming(Envelope envelope) async {
    // BLOCKED(phase-3): decrypt with DartCryptographyService
    final id = '${envelope.from}_${DateTime.now().microsecondsSinceEpoch}';
    await _db.insertMessage(MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(envelope.to),
      senderId: Value(envelope.from),
      payload: Value(envelope.payload),
      createdAt: Value(DateTime.now()),
      isDelivered: const Value(true),
    ));
  }
}

/// Provides access to [_ChatService] for sending messages and watching streams.
final chatProvider = Provider.autoDispose<_ChatService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final ws = ref.watch(wsClientProvider);
  final userId = ref.watch(authProvider.select((s) => s.userId));
  return _ChatService(db: db, wsClient: ws, currentUserId: userId);
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
    return [];
  }

  /// Forward an outbound message through the chat service.
  Future<void> sendMessage(String toId, Uint8List encryptedPayload) async {
    await ref.read(chatProvider).sendMessage(toId, encryptedPayload);
  }
}
