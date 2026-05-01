import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/chat_provider.dart';

/// Shows a persistent amber banner when [WsClient] is disconnected or
/// reconnecting. Animates in/out with a vertical size transition.
///
/// Usage: add as the first child of a [Column] inside a [Scaffold] body.
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(wsClientProvider);

    return StreamBuilder<bool>(
      stream: ws.connectionState,
      initialData: ws.isConnected,
      builder: (context, snapshot) {
        final connected = snapshot.data ?? false;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
          child: connected
              ? const SizedBox.shrink(key: ValueKey('connected'))
              : _BannerContent(
                  pendingCount: ws.pendingMessageCount,
                  key: const ValueKey('disconnected'),
                ),
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({super.key, required this.pendingCount});

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.amber.shade700,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.black87),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⚠ Reconnecting… ($pendingCount messages queued)',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
