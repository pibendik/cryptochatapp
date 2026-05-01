import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../auth/auth_provider.dart';

/// Manages forum post operations: watch from local DB, sync from server,
/// create new posts, and resolve existing posts.
class ForumNotifier {
  ForumNotifier({
    required AppDatabase db,
    required String? sessionToken,
  })  : _db = db,
        _sessionToken = sessionToken;

  final AppDatabase _db;
  final String? _sessionToken;

  /// Live stream of all forum posts, newest first.
  Stream<List<ForumPostsTableData>> watchPosts() => _db.watchForumPosts();

  /// Fetches posts from the server and upserts them into the local DB.
  Future<void> refreshFromServer(String serverUrl) async {
    final token = _sessionToken;
    if (token == null) throw StateError('Not authenticated');

    final response = await http.get(
      Uri.parse('$serverUrl/forum/posts'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch forum posts: ${response.statusCode}');
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    // BLOCKED(phase-3): decrypt post payload with group key before storing plaintextCache
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      await _db.upsertForumPost(ForumPostsTableCompanion(
        id: Value(map['id'] as String),
        authorId: Value(map['author_id'] as String),
        title: Value(map['title'] as String),
        payload: Value(
          map['payload'] != null
              ? base64Decode(map['payload'] as String)
              : Uint8List(0),
        ),
        resolved: Value(map['resolved'] as bool? ?? false),
        createdAt: Value(DateTime.parse(map['created_at'] as String)),
      ));
    }
  }

  /// Posts a new help request to the server and upserts into local DB.
  Future<void> createPost(
    String serverUrl,
    String title,
    Uint8List payload,
  ) async {
    final token = _sessionToken;
    if (token == null) throw StateError('Not authenticated');

    // BLOCKED(phase-3): encrypt payload with group key before posting
    final response = await http.post(
      Uri.parse('$serverUrl/forum/posts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'payload': base64Encode(payload),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create post: ${response.statusCode} ${response.body}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    await _db.upsertForumPost(ForumPostsTableCompanion(
      id: Value(map['id'] as String),
      authorId: Value(map['author_id'] as String),
      title: Value(map['title'] as String),
      payload: Value(
        map['payload'] != null
            ? base64Decode(map['payload'] as String)
            : payload,
      ),
      resolved: Value(map['resolved'] as bool? ?? false),
      createdAt: Value(DateTime.parse(map['created_at'] as String)),
    ));
  }

  /// Marks a post as resolved on the server and updates local DB.
  Future<void> resolvePost(String serverUrl, String postId) async {
    final token = _sessionToken;
    if (token == null) throw StateError('Not authenticated');

    final response = await http.patch(
      Uri.parse('$serverUrl/forum/posts/$postId/resolve'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to resolve post: ${response.statusCode}');
    }

    await _db.markForumPostResolved(postId);
  }
}

/// Provider for [ForumNotifier]. Re-created when auth state changes.
final forumNotifierProvider = Provider<ForumNotifier>((ref) {
  final db = ref.read(appDatabaseProvider);
  final authState = ref.watch(authProvider);
  return ForumNotifier(db: db, sessionToken: authState.sessionToken);
});
