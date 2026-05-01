import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/presence/presence_provider.dart';

/// A small coloured dot showing a user's online/away/offline status.
///
/// Usage: `PresenceDot(userId: contact.id, size: 12.0)`
class PresenceDot extends ConsumerWidget {
  const PresenceDot({super.key, required this.userId, this.size = 12.0});

  final String userId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      presenceProvider.select((map) => map[userId] ?? PresenceStatus.offline),
    );

    return Tooltip(
      message: status.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: status.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
