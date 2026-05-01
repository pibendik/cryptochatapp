import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../chat/chat_provider.dart';

part 'presence_provider.g.dart';

// ── Status enum & extension ───────────────────────────────────────────────

enum PresenceStatus { online, away, offline }

extension PresenceStatusX on PresenceStatus {
  Color get color {
    switch (this) {
      case PresenceStatus.online:
        return const Color(0xFF4CAF50); // green
      case PresenceStatus.away:
        return const Color(0xFFFFC107); // amber
      case PresenceStatus.offline:
        return const Color(0xFF9E9E9E); // grey
    }
  }

  String get label {
    switch (this) {
      case PresenceStatus.online:
        return 'Online';
      case PresenceStatus.away:
        return 'Away';
      case PresenceStatus.offline:
        return 'Offline';
    }
  }

  IconData get icon => Icons.circle;
}

// ── Presence notifier ─────────────────────────────────────────────────────

@riverpod
class Presence extends _$Presence {
  final _statusControllers = <String, StreamController<PresenceStatus>>{};
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  _PresenceLifecycleObserver? _observer;

  @override
  Map<String, PresenceStatus> build() {
    ref.keepAlive();

    final ws = ref.read(wsClientProvider);

    // Subscribe to raw WS messages and filter for presence_update frames.
    _wsSub = ws.rawMessages.listen(_handleRawMessage);

    // Send own-presence updates on app foreground / background transitions.
    _observer = _PresenceLifecycleObserver(
      onForeground: () =>
          ws.sendControl({'type': 'presence', 'status': 'online'}),
      onBackground: () =>
          ws.sendControl({'type': 'presence', 'status': 'away'}),
    );
    WidgetsBinding.instance.addObserver(_observer!);

    ref.onDispose(() {
      _wsSub?.cancel();
      if (_observer != null) {
        WidgetsBinding.instance.removeObserver(_observer!);
      }
      for (final c in _statusControllers.values) {
        c.close();
      }
      _statusControllers.clear();
      // BLOCKED(phase-4): send offline on graceful disconnect / app termination
    });

    return {};
  }

  void _handleRawMessage(Map<String, dynamic> map) {
    if (map['type'] != 'presence_update') return;
    final userId = map['user_id'] as String?;
    final statusStr = map['status'] as String?;
    if (userId == null || statusStr == null) return;

    final status = _parseStatus(statusStr);
    state = {...state, userId: status};
    _statusControllers[userId]?.add(status);
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the known presence status for [userId]; defaults to offline.
  PresenceStatus statusOf(String userId) =>
      state[userId] ?? PresenceStatus.offline;

  /// Emits the current status immediately, then subsequent updates for [userId].
  Stream<PresenceStatus> watchStatus(String userId) async* {
    yield statusOf(userId);
    _statusControllers[userId] ??=
        StreamController<PresenceStatus>.broadcast();
    yield* _statusControllers[userId]!.stream;
  }

  /// True if at least one peer is currently online.
  bool get anyOnline => state.values.any((s) => s == PresenceStatus.online);

  // ── Helpers ───────────────────────────────────────────────────────────────

  static PresenceStatus _parseStatus(String raw) {
    switch (raw) {
      case 'online':
        return PresenceStatus.online;
      case 'away':
        return PresenceStatus.away;
      default:
        return PresenceStatus.offline;
    }
  }
}

// ── App-lifecycle observer ────────────────────────────────────────────────

class _PresenceLifecycleObserver extends WidgetsBindingObserver {
  _PresenceLifecycleObserver({
    required this.onForeground,
    required this.onBackground,
  });

  final VoidCallback onForeground;
  final VoidCallback onBackground;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onForeground();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      onBackground();
    }
  }
}
