import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../auth/auth_provider.dart';

part 'profile_provider.g.dart';

// ── Bio/skills JSON helpers ───────────────────────────────────────────────

/// skillsJson column stores `{"bio":"...","skills":[...]}` so we don't need
/// a separate schema migration for bio.  Legacy plain-array format is handled
/// transparently.
({String bio, List<String> skills}) decodeProfileData(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return (
        bio: decoded['bio'] as String? ?? '',
        skills: (decoded['skills'] as List?)?.cast<String>() ?? [],
      );
    } else if (decoded is List) {
      return (bio: '', skills: decoded.cast<String>());
    }
  } catch (_) {}
  return (bio: '', skills: []);
}

String encodeProfileData(String bio, List<String> skills) =>
    jsonEncode({'bio': bio, 'skills': skills});

// ── Manual stream providers ────────────────────────────────────────────────

final watchProfilesProvider = StreamProvider<List<UserProfilesTableData>>((ref) {
  return ref.read(appDatabaseProvider).watchProfiles();
});

final watchGroupMembersProvider =
    StreamProvider.family<List<UserProfilesTableData>, String>(
        (ref, ownUserId) {
  return ref.read(appDatabaseProvider).watchGroupMembers(ownUserId);
});

// ── ProfileNotifier ────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class ProfileNotifier extends _$ProfileNotifier {
  @override
  AsyncValue<UserProfilesTableData?> build() {
    _loadFromCache();
    return const AsyncValue.loading();
  }

  Future<void> _loadFromCache() async {
    try {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated || authState.userId == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final db = ref.read(appDatabaseProvider);
      final profile = await db.getProfile(authState.userId!);
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Fetch own profile from server and cache in drift.
  Future<void> fetchOwnProfile(String serverUrl) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) return;
    try {
      final res = await http.get(
        Uri.parse('$serverUrl/users/me/profile'),
        headers: {'Authorization': 'Bearer ${authState.sessionToken}'},
      );
      if (res.statusCode == 200) {
        await _cacheProfileJson(
            jsonDecode(res.body) as Map<String, dynamic>);
        await _loadFromCache();
      }
    } catch (_) {}
  }

  /// Fetch all group members from server and cache in drift.
  Future<void> fetchGroupMembers(String serverUrl) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) return;
    try {
      final res = await http.get(
        Uri.parse('$serverUrl/groups/me/members'),
        headers: {'Authorization': 'Bearer ${authState.sessionToken}'},
      );
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body) as List<dynamic>;
      final db = ref.read(appDatabaseProvider);
      for (final item in list.cast<Map<String, dynamic>>()) {
        await db.upsertProfile(UserProfilesTableCompanion.insert(
          userId: item['user_id'] as String,
          displayName: item['display_name'] as String? ?? '',
          skillsJson: Value(encodeProfileData(
            item['bio'] as String? ?? '',
            (item['skills'] as List?)?.cast<String>() ?? [],
          )),
          updatedAt: DateTime.now(),
        ));
      }
    } catch (_) {}
  }

  /// Update own bio + skills on the server, then refresh cache.
  Future<void> updateProfile(
      String serverUrl, String bio, List<String> skills) async {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) return;
    final uid = authState.userId!;
    try {
      final res = await http.put(
        Uri.parse('$serverUrl/users/me/profile'),
        headers: {
          'Authorization': 'Bearer ${authState.sessionToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'bio': bio, 'skills': skills}),
      );
      if (res.statusCode == 200) {
        await _cacheProfileJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      } else {
        // Optimistic local update if server unreachable.
        final db = ref.read(appDatabaseProvider);
        final existing = await db.getProfile(uid);
        await db.upsertProfile(UserProfilesTableCompanion.insert(
          userId: uid,
          displayName: existing?.displayName ?? '',
          skillsJson: Value(encodeProfileData(bio, skills)),
          updatedAt: DateTime.now(),
        ));
      }
    } catch (_) {
      // Optimistic local update on network error.
      final db = ref.read(appDatabaseProvider);
      final existing = await db.getProfile(uid);
      await db.upsertProfile(UserProfilesTableCompanion.insert(
        userId: uid,
        displayName: existing?.displayName ?? '',
        skillsJson: Value(encodeProfileData(bio, skills)),
        updatedAt: DateTime.now(),
      ));
    }
    await _loadFromCache();
  }

  Stream<List<UserProfilesTableData>> watchProfiles() =>
      ref.read(appDatabaseProvider).watchProfiles();

  Stream<List<UserProfilesTableData>> watchGroupMembers() {
    final ownUserId = ref.read(authProvider).userId ?? '';
    return ref.read(appDatabaseProvider).watchGroupMembers(ownUserId);
  }

  Future<UserProfilesTableData?> getProfile(String userId) =>
      ref.read(appDatabaseProvider).getProfile(userId);

  Future<void> _cacheProfileJson(Map<String, dynamic> json) async {
    final db = ref.read(appDatabaseProvider);
    await db.upsertProfile(UserProfilesTableCompanion.insert(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      skillsJson: Value(encodeProfileData(
        json['bio'] as String? ?? '',
        (json['skills'] as List?)?.cast<String>() ?? [],
      )),
      updatedAt: DateTime.now(),
    ));
  }
}
