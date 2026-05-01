import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'features/auth/auth_provider.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/chat/screens/chat_list_screen.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/consensus/screens/proposals_screen.dart';
import 'features/consensus/screens/propose_member_screen.dart';
import 'features/ephemeral/screens/ephemeral_chat_screen.dart';
import 'features/forum/screens/forum_screen.dart';
import 'features/profile/screens/members_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/screens/emergency_revoke_screen.dart';
import 'features/settings/screens/key_rotation_screen.dart';

part 'router.g.dart';

@riverpod
GoRouter router(Ref ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Wait for the auth state to be restored from storage before redirecting.
      if (authState.isLoading) return null;

      final hasKeypair = authState.publicKey != null;
      final isOnboarding = state.matchedLocation == '/onboarding';

      // Send users without a local keypair to the onboarding ceremony.
      if (!hasKeypair && !isOnboarding) return '/onboarding';

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => ChatScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
      GoRoute(
        path: '/ephemeral/:sessionId',
        builder: (context, state) => EphemeralChatScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/forum',
        builder: (context, state) => const ForumScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/members',
        builder: (context, state) => const MembersScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/proposals',
        builder: (context, state) => const ProposalsScreen(),
      ),
      GoRoute(
        path: '/proposals/add',
        builder: (context, state) =>
            const ProposeMemberScreen(action: 'ADD'),
      ),
      GoRoute(
        path: '/proposals/remove',
        builder: (context, state) =>
            const ProposeMemberScreen(action: 'REMOVE'),
      ),
      GoRoute(
        path: '/settings/rotate-key',
        builder: (context, state) => const KeyRotationScreen(),
      ),
      GoRoute(
        path: '/settings/emergency-revoke',
        builder: (context, state) => const EmergencyRevokeScreen(),
      ),
    ],
  );
}
