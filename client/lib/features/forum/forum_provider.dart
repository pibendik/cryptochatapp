import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/crypto/crypto_service.dart';
import '../../core/crypto/mls_group_service.dart';
import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../auth/auth_provider.dart';

/// Well-known group ID used for MLS-encrypting forum post titles.
/// All group members share this MLS group and can decrypt each other's titles
/// once the MLS epoch key is established.
const kForumGroupId = 'forum';

/// Manages forum post operations: watch from local DB, sync from server,
/// create new posts, and resolve existing posts.
class ForumNotifier {
  ForumNotifier({
    required AppDatabase db,
    required String? sessionToken,
    required CryptoService cryptoService,
    required Uint8List? encryptionPublicKey,
    required Uint8List? encryptionPrivateKey,
    required MlsGroupService mlsGroupService,
  })  : _db = db,
        _sessionToken = sessionToken,
        _cryptoService = cryptoService,
        _encryptionPublicKey = encryptionPublicKey,
        _encryptionPrivateKey = encryptionPrivateKey,
        _mlsGroupService = mlsGroupService;

  final AppDatabase _db;
  final String? _sessionToken;
  final CryptoService _cryptoService;
  final Uint8List? _encryptionPublicKey;
  final Uint8List? _encryptionPrivateKey;
  final MlsGroupService _mlsGroupService;

  /// Live stream of all forum posts, newest first.
  Stream<List<ForumPostsTableData>> watchPosts() => _db.watchForumPosts();

  /// Attempts to decrypt a base64-encoded encrypted title.
  ///
  /// First tries MLS group decryption so all members can read each other's
  /// titles. Falls back to self-decryption (ECIES with our own private key) if
  /// MLS is not yet ready. Returns '🔒 [encrypted title]' when both attempts
  /// fail (e.g. key not available or decryption error).
  Future<String> _decryptTitle(String base64Title) async {
    final cipherBytes = base64Decode(base64Title);

    // Try MLS group decrypt — succeeds once the forum MLS epoch is established.
    try {
      final plainBytes =
          await _mlsGroupService.decryptForGroup(kForumGroupId, cipherBytes);
      return utf8.decode(plainBytes);
    } on MlsStateNotReadyException {
      // FALLBACK(mls-not-ready): MLS not yet initialised — fall back to
      // self-decryption so the post author can always read their own titles.
    } catch (_) {
      return '🔒 [encrypted title]';
    }

    // Self-decrypt using our own private key (works only for our own posts).
    final privKey = _encryptionPrivateKey;
    if (privKey == null) return '🔒 [encrypted title]';

    try {
      final plainBytes = await _cryptoService.decrypt(cipherBytes, privKey);
      return utf8.decode(plainBytes);
    } catch (_) {
      return '🔒 [encrypted title]';
    }
  }

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
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      final decryptedTitle = await _decryptTitle(map['title'] as String);
      await _db.upsertForumPost(ForumPostsTableCompanion(
        id: Value(map['id'] as String),
        authorId: Value(map['author_id'] as String),
        title: Value(decryptedTitle),
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

    final pubKey = _encryptionPublicKey;
    if (pubKey == null) throw StateError('Encryption keypair not available');

    // Encrypt the title client-side so the server only sees ciphertext.
    // Try MLS group encryption so all members can decrypt each other's titles.
    // Falls back to self-encryption (ECIES with our own public key) when MLS
    // is not yet initialised.
    final titleBytes = Uint8List.fromList(utf8.encode(title));
    Uint8List encryptedTitleBytes;
    try {
      encryptedTitleBytes =
          await _mlsGroupService.encryptForGroup(kForumGroupId, titleBytes);
    } on MlsStateNotReadyException {
      // FALLBACK(mls-not-ready): MLS group not yet initialised — self-encrypt
      // with our own public key so we can still read our own posts.
      encryptedTitleBytes = await _cryptoService.encrypt(titleBytes, pubKey);
    }
    final encryptedTitleB64 = base64Encode(encryptedTitleBytes);

    // BLOCKED(phase-3): encrypt payload with group key before posting
    final response = await http.post(
      Uri.parse('$serverUrl/forum/posts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': encryptedTitleB64,
        'payload': base64Encode(payload),
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Failed to create post: ${response.statusCode} ${response.body}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    // Decrypt the echoed-back title (we just encrypted it, so this succeeds).
    final storedTitle = await _decryptTitle(map['title'] as String);
    await _db.upsertForumPost(ForumPostsTableCompanion(
      id: Value(map['id'] as String),
      authorId: Value(map['author_id'] as String),
      title: Value(storedTitle),
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
  final crypto = ref.read(cryptoServiceProvider);
  final mlsGroupService = ref.read(mlsGroupServiceProvider);
  return ForumNotifier(
    db: db,
    sessionToken: authState.sessionToken,
    cryptoService: crypto,
    encryptionPublicKey: authState.encryptionPublicKey,
    encryptionPrivateKey: authState.encryptionPrivateKey,
    mlsGroupService: mlsGroupService,
  );
});
