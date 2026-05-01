import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../db/app_database.dart';
import '../models/envelope.dart';
import '../storage/secure_storage_service.dart';

enum WsConnectionState { disconnected, connecting, connected }

typedef EnvelopeHandler = void Function(Envelope envelope);

class _OutboundMessage {
  final int? dbId; // row id in OutboundQueueTable; null if not yet persisted
  final String toId; // recipient user or group UUID
  final Uint8List payload; // encrypted envelope
  final DateTime queuedAt;
  _OutboundMessage({
    this.dbId,
    required this.toId,
    required this.payload,
    DateTime? queuedAt,
  }) : queuedAt = queuedAt ?? DateTime.now();
}

/// WebSocket client with automatic exponential-backoff reconnection.
///
/// Usage:
///   final client = WsClient(uri: Uri.parse('wss://example.com/ws'));
///   client.onEnvelope = (env) { /* handle inbound envelope */ };
///   await client.connect();
///   client.enqueue(recipientId, encryptedPayload);
class WsClient {
  WsClient({
    required this.uri,
    required SecureStorageService secureStorage,
    required AppDatabase db,
    this.maxReconnectDelay = const Duration(seconds: 32),
  })  : _secureStorage = secureStorage,
        _db = db;

  final Uri uri;
  final Duration maxReconnectDelay;
  final SecureStorageService _secureStorage;
  final AppDatabase _db;

  EnvelopeHandler? onEnvelope;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  var _state = WsConnectionState.disconnected;
  WsConnectionState get state => _state;

  bool _disposed = false;
  Duration _reconnectDelay = const Duration(seconds: 1);

  final _stateController =
      StreamController<WsConnectionState>.broadcast();
  Stream<WsConnectionState> get stateStream => _stateController.stream;

  // In-memory queue mirrors the OutboundQueueTable rows for fast FIFO access.
  // On app restart, rows are reloaded from the DB in connect().
  final Queue<_OutboundMessage> _outboundQueue = Queue();

  // ── Public API ────────────────────────────────────────────────────────────

  bool get isConnected => _state == WsConnectionState.connected;
  bool get isCurrentlyConnected => isConnected;

  int get pendingMessageCount => _outboundQueue.length;
  bool get hasPendingMessages => _outboundQueue.isNotEmpty;

  /// Connection state as a [Stream<bool>]: true = connected, false = disconnected.
  /// Use this to show a "connecting..." banner in the chat UI.
  Stream<bool> get connectionState =>
      stateStream.map((s) => s == WsConnectionState.connected);

  Future<void> connect() async {
    if (_state != WsConnectionState.disconnected) return;
    await _loadPersistedQueue();
    await _connect();
  }

  /// Enqueue [payload] (serialised encrypted envelope) for delivery to [toId].
  ///
  /// Persists to [OutboundQueueTable] first so the message survives app restarts.
  /// Always enqueues — even if connected — to maintain FIFO ordering.
  /// If the queue exceeds 500 messages the oldest message is dropped.
  Future<void> enqueue(String toId, Uint8List payload) async {
    if (_outboundQueue.length >= 500) {
      final dropped = _outboundQueue.removeFirst();
      if (dropped.dbId != null) {
        unawaited(_db.deleteOutboundMessage(dropped.dbId!));
      }
      // ignore: avoid_print
      print('WARNING: Outbound queue full, dropping oldest message');
    }
    final now = DateTime.now();
    final dbId = await _db.enqueueOutbound(OutboundQueueTableCompanion(
      toId: Value(toId),
      payload: Value(payload),
      queuedAt: Value(now),
    ));
    _outboundQueue.addLast(
      _OutboundMessage(dbId: dbId, toId: toId, payload: payload, queuedAt: now),
    );
    _drainQueue();
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    await _channel?.sink.close();
    _setState(WsConnectionState.disconnected);
    await _rawInboundController.close();
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    _setState(WsConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _setState(WsConnectionState.connected);
      _reconnectDelay = const Duration(seconds: 1); // reset on success

      // Send auth token as first message (token must not appear in URL/logs)
      final sessionToken = await _secureStorage.getSessionToken();
      if (sessionToken == null) {
        await _channel?.sink.close(4001);
        _setState(WsConnectionState.disconnected);
        return;
      }
      _channel?.sink.add(jsonEncode({'type': 'auth', 'token': sessionToken}));

      // Drain any queued outbound messages after successful auth.
      _drainQueue();

      _sub = _channel!.stream.listen(
        _handleRawMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: () {
          if (!_disposed) _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _drainQueue() {
    if (!isConnected) return;
    while (_outboundQueue.isNotEmpty) {
      final msg = _outboundQueue.first;
      try {
        final envelope = jsonEncode({
          'type': 'send',
          'to': msg.toId,
          'payload': base64Encode(msg.payload),
        });
        _channel!.sink.add(envelope);
        _outboundQueue.removeFirst();
        if (msg.dbId != null) {
          unawaited(_db.deleteOutboundMessage(msg.dbId!));
        }
      } catch (e) {
        // Send failed — stop draining, message stays at front of queue.
        // Will retry on next _drainQueue() call after reconnect.
        break;
      }
    }
  }

  /// Loads any rows persisted in [OutboundQueueTable] into the front of the
  /// in-memory queue so they are retried before any newly-enqueued messages.
  /// Called once by [connect()] on the first connection attempt after app start.
  Future<void> _loadPersistedQueue() async {
    final rows = await _db.getPendingOutbound();
    for (final row in rows.reversed) {
      _outboundQueue.addFirst(_OutboundMessage(
        dbId: row.id,
        toId: row.toId,
        payload: row.payload,
        queuedAt: row.queuedAt,
      ));
    }
  }

  // ── Raw inbound message stream (presence updates, etc.) ──────────────────

  final _rawInboundController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast stream of every raw JSON object received from the server,
  /// including non-Envelope messages such as `presence_update`.
  Stream<Map<String, dynamic>> get rawMessages => _rawInboundController.stream;

  void _handleRawMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      _rawInboundController.add(map);
      final envelope = Envelope.fromJson(map);
      onEnvelope?.call(envelope);
    } catch (_) {
      // TODO: log parse errors via a proper logger, not print
    }
  }

  /// Send a control/signalling message (e.g. presence heartbeat) directly.
  /// No-op if the socket is not currently connected.
  void sendControl(Map<String, dynamic> data) {
    if (!isConnected) return;
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {
      // Ignore send failures — caller may retry.
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setState(WsConnectionState.disconnected);
    Future.delayed(_reconnectDelay, () {
      if (!_disposed) {
        _connect();
      }
    });
    // Exponential backoff: double delay, cap at maxReconnectDelay
    _reconnectDelay = Duration(
      seconds: (_reconnectDelay.inSeconds * 2)
          .clamp(1, maxReconnectDelay.inSeconds),
    );
  }

  void _setState(WsConnectionState next) {
    _state = next;
    _stateController.add(next);
  }
}
