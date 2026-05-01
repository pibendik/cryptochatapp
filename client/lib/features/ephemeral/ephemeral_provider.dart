import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/ws_client.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import 'ephemeral_session.dart';

/// Manages the list of active/raised ephemeral help-request sessions.
///
/// Handles server HTTP calls and routes relevant WS events into state.
class EphemeralNotifier extends StateNotifier<List<EphemeralSession>> {
  EphemeralNotifier({
    required String serverUrl,
    required String? sessionToken,
    required WsClient wsClient,
  })  : _serverUrl = serverUrl,
        _sessionToken = sessionToken,
        super([]) {
    _wsSubscription = wsClient.rawMessages.listen(_handleWsEvent);
  }

  final String _serverUrl;
  final String? _sessionToken;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// POST /ephemeral/raise — creates a new help-request session.
  Future<EphemeralSession> raiseFlag() async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/ephemeral/raise'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    );
    _checkStatus(response, 'raise flag');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final session = EphemeralSession.fromJson(
      data['session'] as Map<String, dynamic>,
    );
    state = [...state, session];
    return session;
  }

  /// POST /ephemeral/:id/join — joins an existing session.
  Future<EphemeralSession> joinSession(String sessionId) async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/ephemeral/$sessionId/join'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkStatus(response, 'join session');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final updated = EphemeralSession.fromJson(
      data['session'] as Map<String, dynamic>,
    );
    state = [
      for (final s in state)
        if (s.id == sessionId) updated else s,
      if (!state.any((s) => s.id == sessionId)) updated,
    ];
    return updated;
  }

  /// POST /ephemeral/:id/close — closes a session and removes it from state.
  Future<void> closeSession(String sessionId) async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/ephemeral/$sessionId/close'),
      headers: {'Authorization': 'Bearer $token'},
    );
    // Idempotent — 200 whether it existed or not.
    if (response.statusCode != 200) {
      throw Exception('Failed to close session: ${response.statusCode}');
    }
    state = state.where((s) => s.id != sessionId).toList();
  }

  /// GET /ephemeral/active — refresh the list of active/raised sessions.
  Future<void> refreshActive() async {
    final token = _requireToken();
    final response = await http.get(
      Uri.parse('$_serverUrl/ephemeral/active'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkStatus(response, 'list active sessions');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final sessions = (data['sessions'] as List<dynamic>)
        .map((e) => EphemeralSession.fromJson(e as Map<String, dynamic>))
        .toList();
    state = sessions;
  }

  // ── WS event routing ──────────────────────────────────────────────────────

  void _handleWsEvent(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'ephemeral_raised':
        _onEphemeralRaised(msg);
      case 'ephemeral_joined':
        _onEphemeralJoined(msg);
      case 'ephemeral_deleted':
        _onEphemeralDeleted(msg);
    }
  }

  void _onEphemeralRaised(Map<String, dynamic> msg) {
    final sessionId = msg['sessionId'] as String?;
    final creatorId = msg['creatorId'] as String?;
    if (sessionId == null || creatorId == null) return;

    // Add to state only if not already present.
    if (state.any((s) => s.id == sessionId)) return;
    state = [
      ...state,
      EphemeralSession(
        id: sessionId,
        creatorId: creatorId,
        state: EphemeralSessionState.raised,
        participants: const <String>[],
        createdAt: DateTime.now(),
      ),
    ];
  }

  void _onEphemeralJoined(Map<String, dynamic> msg) {
    final sessionId = msg['sessionId'] as String?;
    final userId = msg['userId'] as String?;
    if (sessionId == null || userId == null) return;

    state = [
      for (final s in state)
        if (s.id == sessionId)
          s.copyWith(
            state: EphemeralSessionState.active,
            participants: [
              ...s.participants,
              if (!s.participants.contains(userId)) userId,
            ],
          )
        else
          s,
    ];
  }

  void _onEphemeralDeleted(Map<String, dynamic> msg) {
    final sessionId = msg['sessionId'] as String?;
    if (sessionId == null) return;
    state = state.where((s) => s.id != sessionId).toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _requireToken() {
    final token = _sessionToken;
    if (token == null) throw StateError('Not authenticated');
    return token;
  }

  void _checkStatus(http.Response response, String operation) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to $operation: ${response.statusCode} ${response.body}',
      );
    }
  }
}

/// Provider for [EphemeralNotifier]. Re-created on auth-state change.
final ephemeralProvider =
    StateNotifierProvider<EphemeralNotifier, List<EphemeralSession>>((ref) {
  final serverUrl = ref.watch(appConfigProvider).serverUrl;
  final token = ref.watch(authProvider.select((s) => s.sessionToken));
  final ws = ref.read(wsClientProvider);
  return EphemeralNotifier(
    serverUrl: serverUrl,
    sessionToken: token,
    wsClient: ws,
  );
});
