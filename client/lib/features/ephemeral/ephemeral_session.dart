import 'package:flutter/foundation.dart';

/// State of an ephemeral help-request session.
enum EphemeralSessionState { raised, active, closed }

extension EphemeralSessionStateX on EphemeralSessionState {
  static EphemeralSessionState fromString(String s) {
    switch (s.toUpperCase()) {
      case 'ACTIVE':
        return EphemeralSessionState.active;
      case 'CLOSED':
        return EphemeralSessionState.closed;
      default:
        return EphemeralSessionState.raised;
    }
  }

  String get label {
    switch (this) {
      case EphemeralSessionState.raised:
        return 'RAISED';
      case EphemeralSessionState.active:
        return 'ACTIVE';
      case EphemeralSessionState.closed:
        return 'CLOSED';
    }
  }
}

/// Represents an ephemeral help-request chat session.
@immutable
class EphemeralSession {
  const EphemeralSession({
    required this.id,
    required this.creatorId,
    required this.state,
    required this.participants,
    required this.createdAt,
  });

  /// Server-assigned UUID for the session.
  final String id;

  /// User ID (UUID string) of the person who raised the flag.
  final String creatorId;

  final EphemeralSessionState state;

  /// User IDs of all current participants.
  final List<String> participants;

  final DateTime createdAt;

  EphemeralSession copyWith({
    String? id,
    String? creatorId,
    EphemeralSessionState? state,
    List<String>? participants,
    DateTime? createdAt,
  }) {
    return EphemeralSession(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      state: state ?? this.state,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory EphemeralSession.fromJson(Map<String, dynamic> json) {
    return EphemeralSession(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      state: EphemeralSessionStateX.fromString(
        (json['state'] as String?) ?? 'RAISED',
      ),
      participants: const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
