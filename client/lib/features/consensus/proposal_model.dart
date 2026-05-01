import 'package:flutter/foundation.dart';

/// State of a member add/remove proposal.
enum ProposalState { pending, approved, rejected, expired }

extension ProposalStateX on ProposalState {
  static ProposalState fromString(String s) {
    switch (s.toUpperCase()) {
      case 'APPROVED':
        return ProposalState.approved;
      case 'REJECTED':
        return ProposalState.rejected;
      case 'EXPIRED':
        return ProposalState.expired;
      default:
        return ProposalState.pending;
    }
  }
}

/// A vote cast by a member on a proposal.
@immutable
class ProposalVote {
  const ProposalVote({
    required this.voterKeyHex,
    required this.vote,
    required this.votedAt,
  });

  final String voterKeyHex;
  final String vote; // 'APPROVE' | 'REJECT'
  final DateTime votedAt;

  factory ProposalVote.fromJson(Map<String, dynamic> json) {
    return ProposalVote(
      voterKeyHex: json['voter_key_hex'] as String,
      vote: json['vote'] as String,
      votedAt: json['voted_at'] != null
          ? DateTime.parse(json['voted_at'] as String)
          : DateTime.now(),
    );
  }
}

/// A member add/remove proposal.
@immutable
class MemberProposal {
  const MemberProposal({
    required this.id,
    required this.groupId,
    required this.action,
    required this.targetKeyHex,
    this.targetLabel,
    required this.proposedBy,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
    this.votes = const [],
    this.approveCount = 0,
    this.rejectCount = 0,
  });

  final String id;
  final String groupId;
  final String action; // 'ADD' | 'REMOVE'
  final String targetKeyHex;
  final String? targetLabel;
  final String proposedBy;
  final ProposalState state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<ProposalVote> votes;
  final int approveCount;
  final int rejectCount;

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  MemberProposal copyWith({
    ProposalState? state,
    List<ProposalVote>? votes,
    int? approveCount,
    int? rejectCount,
  }) {
    return MemberProposal(
      id: id,
      groupId: groupId,
      action: action,
      targetKeyHex: targetKeyHex,
      targetLabel: targetLabel,
      proposedBy: proposedBy,
      state: state ?? this.state,
      createdAt: createdAt,
      expiresAt: expiresAt,
      votes: votes ?? this.votes,
      approveCount: approveCount ?? this.approveCount,
      rejectCount: rejectCount ?? this.rejectCount,
    );
  }

  factory MemberProposal.fromJson(Map<String, dynamic> json) {
    final votesList = (json['votes'] as List<dynamic>?)
        ?.map((v) => ProposalVote.fromJson(v as Map<String, dynamic>))
        .toList() ??
        [];

    return MemberProposal(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      action: json['action'] as String,
      targetKeyHex: json['target_key_hex'] as String,
      targetLabel: json['target_label'] as String?,
      proposedBy: json['proposed_by'] as String,
      state: ProposalStateX.fromString(
        (json['state'] as String?) ?? 'PENDING',
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now().add(const Duration(hours: 48)),
      votes: votesList,
      approveCount: (json['approve_count'] as num?)?.toInt() ?? votesList.where((v) => v.vote == 'APPROVE').length,
      rejectCount: (json['reject_count'] as num?)?.toInt() ?? votesList.where((v) => v.vote == 'REJECT').length,
    );
  }
}
