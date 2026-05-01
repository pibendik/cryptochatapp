import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/network/ws_client.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import 'proposal_model.dart';

/// Manages the list of member add/remove proposals for the current group.
///
/// Handles HTTP calls to the consensus API and routes relevant WS events.
class ConsensusNotifier extends StateNotifier<List<MemberProposal>> {
  ConsensusNotifier({
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

  /// POST /consensus/propose — submit a proposal to add a new member.
  Future<MemberProposal> proposeMemberAdd(String keyHex, String label) async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/consensus/propose'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': 'ADD',
        'target_key_hex': keyHex,
        'target_label': label,
      }),
    );
    _checkStatus(response, 'propose member add');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final proposal = MemberProposal.fromJson(
      data['proposal'] as Map<String, dynamic>,
    );
    state = [...state, proposal];
    return proposal;
  }

  /// POST /consensus/propose — submit a proposal to remove an existing member.
  Future<MemberProposal> proposeMemberRemove(String keyHex,
      {String? label}) async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/consensus/propose'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'action': 'REMOVE',
        'target_key_hex': keyHex,
        if (label != null) 'target_label': label,
      }),
    );
    _checkStatus(response, 'propose member remove');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final proposal = MemberProposal.fromJson(
      data['proposal'] as Map<String, dynamic>,
    );
    state = [...state, proposal];
    return proposal;
  }

  /// POST /consensus/proposals/:id/vote — cast APPROVE or REJECT.
  Future<void> castVote(String proposalId, {required bool approve}) async {
    final token = _requireToken();
    final response = await http.post(
      Uri.parse('$_serverUrl/consensus/proposals/$proposalId/vote'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'approve': approve}),
    );
    _checkStatus(response, 'cast vote');
    // Reload the proposal to get updated vote counts.
    await _reloadProposal(proposalId);
  }

  /// GET /consensus/proposals — load open proposals for the user's group.
  Future<void> loadProposals() async {
    final token = _requireToken();
    final response = await http.get(
      Uri.parse('$_serverUrl/consensus/proposals'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _checkStatus(response, 'load proposals');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final proposals = (data['proposals'] as List<dynamic>)
        .map((e) => MemberProposal.fromJson(e as Map<String, dynamic>))
        .toList();
    state = proposals;
  }

  // ── WS event routing ──────────────────────────────────────────────────────

  void _handleWsEvent(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    switch (type) {
      case 'proposal_created':
        _onProposalCreated(msg);
      case 'proposal_approved':
        _onProposalResolved(msg, approved: true);
      case 'proposal_rejected':
        _onProposalResolved(msg, approved: false);
      case 'member_removed':
        _onProposalResolved(msg, approved: true);
    }
  }

  void _onProposalCreated(Map<String, dynamic> msg) {
    final proposalId = msg['proposalId'] as String?;
    if (proposalId == null) return;
    if (state.any((p) => p.id == proposalId)) return;

    final action = msg['action'] as String? ?? 'ADD';
    final targetKeyHex = msg['targetKeyHex'] as String? ?? '';
    final targetLabel = msg['targetLabel'] as String?;
    final proposedBy = msg['proposedBy'] as String? ?? '';

    state = [
      ...state,
      MemberProposal(
        id: proposalId,
        groupId: '',
        action: action,
        targetKeyHex: targetKeyHex,
        targetLabel: targetLabel,
        proposedBy: proposedBy,
        state: ProposalState.pending,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
        approveCount: 1, // proposer auto-approves
      ),
    ];
  }

  void _onProposalResolved(
    Map<String, dynamic> msg, {
    required bool approved,
  }) {
    final proposalId = msg['proposalId'] as String?;
    if (proposalId == null) return;
    // Remove resolved proposals from the pending list.
    state = state.where((p) => p.id != proposalId).toList();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _reloadProposal(String proposalId) async {
    final token = _requireToken();
    final response = await http.get(
      Uri.parse('$_serverUrl/consensus/proposals/$proposalId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final updated = MemberProposal.fromJson(data);
      state = [
        for (final p in state)
          if (p.id == proposalId) updated else p,
      ];
    } else if (response.statusCode == 404) {
      // Proposal resolved and removed.
      state = state.where((p) => p.id != proposalId).toList();
    }
  }

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

/// Provider for [ConsensusNotifier]. Re-created on auth-state change.
final consensusProvider =
    StateNotifierProvider<ConsensusNotifier, List<MemberProposal>>((ref) {
  final serverUrl = ref.watch(appConfigProvider).serverUrl;
  final token = ref.watch(authProvider.select((s) => s.sessionToken));
  final ws = ref.read(wsClientProvider);
  return ConsensusNotifier(
    serverUrl: serverUrl,
    sessionToken: token,
    wsClient: ws,
  );
});
