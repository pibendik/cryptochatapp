import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/app_database.dart';
import '../../core/db/database_provider.dart';
import '../../core/models/contact.dart';

part 'contacts_provider.g.dart';

// BLOCKED(phase-2): migrate remaining SecureStorage blobs (session token, keypairs) to drift or keep in SecureStorage for key material

/// Thrown when [Contacts.addContact] is called for a signing key already stored.
class DuplicateContactException implements Exception {
  const DuplicateContactException(this.displayName);
  final String displayName;

  @override
  String toString() => 'DuplicateContactException: $displayName already in contacts';
}

@riverpod
class Contacts extends _$Contacts {
  @override
  Future<List<Contact>> build() => _loadContacts();

  Future<List<Contact>> _loadContacts() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await db.getAllContacts();
    return rows.map(_rowToContact).toList();
  }

  List<Contact> get allContacts => state.valueOrNull ?? [];

  /// Add [contact] and persist to the local database.
  ///
  /// Throws [DuplicateContactException] if a contact with the same signing
  /// key already exists.
  Future<void> addContact(Contact contact) async {
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getContactById(contact.id);
    if (existing != null) {
      throw DuplicateContactException(contact.displayName);
    }
    await db.upsertContact(ContactsTableCompanion(
      id: Value(contact.id),
      displayName: Value(contact.displayName),
      signingPublicKey: Value(contact.signingPublicKey),
      encryptionPublicKey: Value(contact.encryptionPublicKey),
      verifiedAt: Value(contact.verifiedAt),
    ));
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, contact]);
  }

  static Contact _rowToContact(ContactsTableData row) => Contact(
        id: row.id,
        displayName: row.displayName,
        signingPublicKey: row.signingPublicKey,
        encryptionPublicKey: row.encryptionPublicKey,
        verifiedAt: row.verifiedAt,
      );
}
