import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

// ── Tables ────────────────────────────────────────────────────────────────────

class ContactsTable extends Table {
  TextColumn get id => text()(); // hex signing key — primary identity
  TextColumn get displayName => text()();
  BlobColumn get signingPublicKey => blob()();
  BlobColumn get encryptionPublicKey => blob()();
  DateTimeColumn get verifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MessagesTable extends Table {
  TextColumn get id => text()(); // server-assigned UUID
  TextColumn get conversationId => text()(); // group_id or peer user_id
  TextColumn get senderId => text()();
  BlobColumn get payload => blob()(); // ALWAYS ciphertext — decrypt before display
  BlobColumn get plaintextCache => blob().nullable()(); // decrypted content, null until decrypted
  // BLOCKED(phase-3): plaintextCache must be cleared on MLS epoch rotation
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isDelivered => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class ForumPostsTable extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text()();
  TextColumn get title => text()();
  BlobColumn get payload => blob()(); // encrypted body — ALWAYS ciphertext
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class UserProfilesTable extends Table {
  TextColumn get userId => text()(); // server UUID
  TextColumn get displayName => text()();
  TextColumn get skillsJson => text().withDefault(const Constant('[]'))();
  // skills stored as JSON array of strings — e.g. ["cooking","programming","first aid"]
  TextColumn get availability => text().withDefault(const Constant('online'))();
  // BLOCKED(phase-2): availability should come from WS presence_update, not profile storage
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

class OutboundQueueTable extends Table {
  // BLOCKED(phase-2): this table is the outbound WS message queue
  // populated by ws_client.dart when disconnected, drained on reconnect
  IntColumn get id => integer().autoIncrement()();
  TextColumn get toId => text()(); // recipient user or group UUID
  BlobColumn get payload => blob()(); // encrypted envelope payload
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

// ── Database ──────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  ContactsTable,
  MessagesTable,
  ForumPostsTable,
  UserProfilesTable,
  OutboundQueueTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ── Contacts ──
  Future<List<ContactsTableData>> getAllContacts() =>
      select(contactsTable).get();

  Future<void> upsertContact(ContactsTableCompanion contact) =>
      into(contactsTable).insertOnConflictUpdate(contact);

  Future<ContactsTableData?> getContactById(String id) =>
      (select(contactsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  // ── Messages ──
  Stream<List<MessagesTableData>> watchConversation(String conversationId) =>
      (select(messagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// Returns a stream of the single most-recent message in [conversationId],
  /// or null when the conversation has no messages yet.
  Stream<MessagesTableData?> watchLastMessage(String conversationId) =>
      (select(messagesTable)
            ..where((t) => t.conversationId.equals(conversationId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<void> insertMessage(MessagesTableCompanion msg) =>
      into(messagesTable).insertOnConflictUpdate(msg);

  Future<void> updatePlaintextCache(String id, Uint8List plaintext) =>
      (update(messagesTable)..where((t) => t.id.equals(id)))
          .write(MessagesTableCompanion(plaintextCache: Value(plaintext)));

  /// Clears [MessagesTable.plaintextCache] for every message in [groupId].
  ///
  /// Called by MlsService.onEpochRotation — must be atomic with epoch key rotation.
  /// After an MLS epoch transition the previous epoch's key material is gone, so
  /// any cached plaintext is no longer verifiable and must be re-decrypted.
  Future<void> clearPlaintextCacheForGroup(String groupId) =>
      (update(messagesTable)..where((m) => m.conversationId.equals(groupId)))
          .write(const MessagesTableCompanion(plaintextCache: Value(null)));

  // ── Forum posts ──
  Stream<List<ForumPostsTableData>> watchForumPosts() =>
      (select(forumPostsTable)
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertForumPost(ForumPostsTableCompanion post) =>
      into(forumPostsTable).insertOnConflictUpdate(post);

  Future<void> markForumPostResolved(String postId) =>
      (update(forumPostsTable)..where((t) => t.id.equals(postId)))
          .write(const ForumPostsTableCompanion(resolved: Value(true)));

  // ── Profiles ──
  Future<void> upsertProfile(UserProfilesTableCompanion profile) =>
      into(userProfilesTable).insertOnConflictUpdate(profile);

  Future<UserProfilesTableData?> getProfile(String userId) =>
      (select(userProfilesTable)..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

  Stream<List<UserProfilesTableData>> watchProfiles() =>
      select(userProfilesTable).watch();

  Stream<List<UserProfilesTableData>> watchGroupMembers(String ownUserId) =>
      (select(userProfilesTable)
            ..where((t) => t.userId.isNotValue(ownUserId)))
          .watch();

  // ── Outbound queue ──
  Future<List<OutboundQueueTableData>> getPendingOutbound() =>
      (select(outboundQueueTable)
            ..orderBy([(t) => OrderingTerm.asc(t.queuedAt)]))
          .get();

  Future<int> enqueueOutbound(OutboundQueueTableCompanion msg) =>
      into(outboundQueueTable).insert(msg);

  Future<void> deleteOutboundMessage(int id) =>
      (delete(outboundQueueTable)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cryptochat.db'));
    return NativeDatabase.createInBackground(file);
  });
}
