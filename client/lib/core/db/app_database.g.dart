// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContactsTableTable extends ContactsTable
    with TableInfo<$ContactsTableTable, ContactsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _signingPublicKeyMeta =
      const VerificationMeta('signingPublicKey');
  @override
  late final GeneratedColumn<Uint8List> signingPublicKey =
      GeneratedColumn<Uint8List>('signing_public_key', aliasedName, false,
          type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _encryptionPublicKeyMeta =
      const VerificationMeta('encryptionPublicKey');
  @override
  late final GeneratedColumn<Uint8List> encryptionPublicKey =
      GeneratedColumn<Uint8List>('encryption_public_key', aliasedName, false,
          type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _verifiedAtMeta =
      const VerificationMeta('verifiedAt');
  @override
  late final GeneratedColumn<DateTime> verifiedAt = GeneratedColumn<DateTime>(
      'verified_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, displayName, signingPublicKey, encryptionPublicKey, verifiedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts_table';
  @override
  VerificationContext validateIntegrity(Insertable<ContactsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('signing_public_key')) {
      context.handle(
          _signingPublicKeyMeta,
          signingPublicKey.isAcceptableOrUnknown(
              data['signing_public_key']!, _signingPublicKeyMeta));
    } else if (isInserting) {
      context.missing(_signingPublicKeyMeta);
    }
    if (data.containsKey('encryption_public_key')) {
      context.handle(
          _encryptionPublicKeyMeta,
          encryptionPublicKey.isAcceptableOrUnknown(
              data['encryption_public_key']!, _encryptionPublicKeyMeta));
    } else if (isInserting) {
      context.missing(_encryptionPublicKeyMeta);
    }
    if (data.containsKey('verified_at')) {
      context.handle(
          _verifiedAtMeta,
          verifiedAt.isAcceptableOrUnknown(
              data['verified_at']!, _verifiedAtMeta));
    } else if (isInserting) {
      context.missing(_verifiedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      signingPublicKey: attachedDatabase.typeMapping.read(
          DriftSqlType.blob, data['${effectivePrefix}signing_public_key'])!,
      encryptionPublicKey: attachedDatabase.typeMapping.read(
          DriftSqlType.blob, data['${effectivePrefix}encryption_public_key'])!,
      verifiedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}verified_at'])!,
    );
  }

  @override
  $ContactsTableTable createAlias(String alias) {
    return $ContactsTableTable(attachedDatabase, alias);
  }
}

class ContactsTableData extends DataClass
    implements Insertable<ContactsTableData> {
  final String id;
  final String displayName;
  final Uint8List signingPublicKey;
  final Uint8List encryptionPublicKey;
  final DateTime verifiedAt;
  const ContactsTableData(
      {required this.id,
      required this.displayName,
      required this.signingPublicKey,
      required this.encryptionPublicKey,
      required this.verifiedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['signing_public_key'] = Variable<Uint8List>(signingPublicKey);
    map['encryption_public_key'] = Variable<Uint8List>(encryptionPublicKey);
    map['verified_at'] = Variable<DateTime>(verifiedAt);
    return map;
  }

  ContactsTableCompanion toCompanion(bool nullToAbsent) {
    return ContactsTableCompanion(
      id: Value(id),
      displayName: Value(displayName),
      signingPublicKey: Value(signingPublicKey),
      encryptionPublicKey: Value(encryptionPublicKey),
      verifiedAt: Value(verifiedAt),
    );
  }

  factory ContactsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactsTableData(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      signingPublicKey:
          serializer.fromJson<Uint8List>(json['signingPublicKey']),
      encryptionPublicKey:
          serializer.fromJson<Uint8List>(json['encryptionPublicKey']),
      verifiedAt: serializer.fromJson<DateTime>(json['verifiedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'signingPublicKey': serializer.toJson<Uint8List>(signingPublicKey),
      'encryptionPublicKey': serializer.toJson<Uint8List>(encryptionPublicKey),
      'verifiedAt': serializer.toJson<DateTime>(verifiedAt),
    };
  }

  ContactsTableData copyWith(
          {String? id,
          String? displayName,
          Uint8List? signingPublicKey,
          Uint8List? encryptionPublicKey,
          DateTime? verifiedAt}) =>
      ContactsTableData(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        signingPublicKey: signingPublicKey ?? this.signingPublicKey,
        encryptionPublicKey: encryptionPublicKey ?? this.encryptionPublicKey,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );
  @override
  String toString() {
    return (StringBuffer('ContactsTableData(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('signingPublicKey: $signingPublicKey, ')
          ..write('encryptionPublicKey: $encryptionPublicKey, ')
          ..write('verifiedAt: $verifiedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      displayName,
      $driftBlobEquality.hash(signingPublicKey),
      $driftBlobEquality.hash(encryptionPublicKey),
      verifiedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactsTableData &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          $driftBlobEquality.equals(
              other.signingPublicKey, this.signingPublicKey) &&
          $driftBlobEquality.equals(
              other.encryptionPublicKey, this.encryptionPublicKey) &&
          other.verifiedAt == this.verifiedAt);
}

class ContactsTableCompanion extends UpdateCompanion<ContactsTableData> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<Uint8List> signingPublicKey;
  final Value<Uint8List> encryptionPublicKey;
  final Value<DateTime> verifiedAt;
  final Value<int> rowid;
  const ContactsTableCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.signingPublicKey = const Value.absent(),
    this.encryptionPublicKey = const Value.absent(),
    this.verifiedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsTableCompanion.insert({
    required String id,
    required String displayName,
    required Uint8List signingPublicKey,
    required Uint8List encryptionPublicKey,
    required DateTime verifiedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        displayName = Value(displayName),
        signingPublicKey = Value(signingPublicKey),
        encryptionPublicKey = Value(encryptionPublicKey),
        verifiedAt = Value(verifiedAt);
  static Insertable<ContactsTableData> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<Uint8List>? signingPublicKey,
    Expression<Uint8List>? encryptionPublicKey,
    Expression<DateTime>? verifiedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (signingPublicKey != null) 'signing_public_key': signingPublicKey,
      if (encryptionPublicKey != null)
        'encryption_public_key': encryptionPublicKey,
      if (verifiedAt != null) 'verified_at': verifiedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? displayName,
      Value<Uint8List>? signingPublicKey,
      Value<Uint8List>? encryptionPublicKey,
      Value<DateTime>? verifiedAt,
      Value<int>? rowid}) {
    return ContactsTableCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      signingPublicKey: signingPublicKey ?? this.signingPublicKey,
      encryptionPublicKey: encryptionPublicKey ?? this.encryptionPublicKey,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (signingPublicKey.present) {
      map['signing_public_key'] = Variable<Uint8List>(signingPublicKey.value);
    }
    if (encryptionPublicKey.present) {
      map['encryption_public_key'] =
          Variable<Uint8List>(encryptionPublicKey.value);
    }
    if (verifiedAt.present) {
      map['verified_at'] = Variable<DateTime>(verifiedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsTableCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('signingPublicKey: $signingPublicKey, ')
          ..write('encryptionPublicKey: $encryptionPublicKey, ')
          ..write('verifiedAt: $verifiedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTableTable extends MessagesTable
    with TableInfo<$MessagesTableTable, MessagesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
      'payload', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _plaintextCacheMeta =
      const VerificationMeta('plaintextCache');
  @override
  late final GeneratedColumn<Uint8List> plaintextCache =
      GeneratedColumn<Uint8List>('plaintext_cache', aliasedName, true,
          type: DriftSqlType.blob, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _isDeliveredMeta =
      const VerificationMeta('isDelivered');
  @override
  late final GeneratedColumn<bool> isDelivered = GeneratedColumn<bool>(
      'is_delivered', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_delivered" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        conversationId,
        senderId,
        payload,
        plaintextCache,
        createdAt,
        isDelivered
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages_table';
  @override
  VerificationContext validateIntegrity(Insertable<MessagesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    } else if (isInserting) {
      context.missing(_senderIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('plaintext_cache')) {
      context.handle(
          _plaintextCacheMeta,
          plaintextCache.isAcceptableOrUnknown(
              data['plaintext_cache']!, _plaintextCacheMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_delivered')) {
      context.handle(
          _isDeliveredMeta,
          isDelivered.isAcceptableOrUnknown(
              data['is_delivered']!, _isDeliveredMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessagesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessagesTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}payload'])!,
      plaintextCache: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}plaintext_cache']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      isDelivered: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_delivered'])!,
    );
  }

  @override
  $MessagesTableTable createAlias(String alias) {
    return $MessagesTableTable(attachedDatabase, alias);
  }
}

class MessagesTableData extends DataClass
    implements Insertable<MessagesTableData> {
  final String id;
  final String conversationId;
  final String senderId;
  final Uint8List payload;
  final Uint8List? plaintextCache;
  final DateTime createdAt;
  final bool isDelivered;
  const MessagesTableData(
      {required this.id,
      required this.conversationId,
      required this.senderId,
      required this.payload,
      this.plaintextCache,
      required this.createdAt,
      required this.isDelivered});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_id'] = Variable<String>(senderId);
    map['payload'] = Variable<Uint8List>(payload);
    if (!nullToAbsent || plaintextCache != null) {
      map['plaintext_cache'] = Variable<Uint8List>(plaintextCache);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_delivered'] = Variable<bool>(isDelivered);
    return map;
  }

  MessagesTableCompanion toCompanion(bool nullToAbsent) {
    return MessagesTableCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderId: Value(senderId),
      payload: Value(payload),
      plaintextCache: plaintextCache == null && nullToAbsent
          ? const Value.absent()
          : Value(plaintextCache),
      createdAt: Value(createdAt),
      isDelivered: Value(isDelivered),
    );
  }

  factory MessagesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessagesTableData(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderId: serializer.fromJson<String>(json['senderId']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      plaintextCache: serializer.fromJson<Uint8List?>(json['plaintextCache']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDelivered: serializer.fromJson<bool>(json['isDelivered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderId': serializer.toJson<String>(senderId),
      'payload': serializer.toJson<Uint8List>(payload),
      'plaintextCache': serializer.toJson<Uint8List?>(plaintextCache),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDelivered': serializer.toJson<bool>(isDelivered),
    };
  }

  MessagesTableData copyWith(
          {String? id,
          String? conversationId,
          String? senderId,
          Uint8List? payload,
          Value<Uint8List?> plaintextCache = const Value.absent(),
          DateTime? createdAt,
          bool? isDelivered}) =>
      MessagesTableData(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        payload: payload ?? this.payload,
        plaintextCache:
            plaintextCache.present ? plaintextCache.value : this.plaintextCache,
        createdAt: createdAt ?? this.createdAt,
        isDelivered: isDelivered ?? this.isDelivered,
      );
  @override
  String toString() {
    return (StringBuffer('MessagesTableData(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('payload: $payload, ')
          ..write('plaintextCache: $plaintextCache, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDelivered: $isDelivered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      conversationId,
      senderId,
      $driftBlobEquality.hash(payload),
      $driftBlobEquality.hash(plaintextCache),
      createdAt,
      isDelivered);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessagesTableData &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderId == this.senderId &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          $driftBlobEquality.equals(
              other.plaintextCache, this.plaintextCache) &&
          other.createdAt == this.createdAt &&
          other.isDelivered == this.isDelivered);
}

class MessagesTableCompanion extends UpdateCompanion<MessagesTableData> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderId;
  final Value<Uint8List> payload;
  final Value<Uint8List?> plaintextCache;
  final Value<DateTime> createdAt;
  final Value<bool> isDelivered;
  final Value<int> rowid;
  const MessagesTableCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.payload = const Value.absent(),
    this.plaintextCache = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDelivered = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesTableCompanion.insert({
    required String id,
    required String conversationId,
    required String senderId,
    required Uint8List payload,
    this.plaintextCache = const Value.absent(),
    required DateTime createdAt,
    this.isDelivered = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        senderId = Value(senderId),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<MessagesTableData> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderId,
    Expression<Uint8List>? payload,
    Expression<Uint8List>? plaintextCache,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDelivered,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderId != null) 'sender_id': senderId,
      if (payload != null) 'payload': payload,
      if (plaintextCache != null) 'plaintext_cache': plaintextCache,
      if (createdAt != null) 'created_at': createdAt,
      if (isDelivered != null) 'is_delivered': isDelivered,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? conversationId,
      Value<String>? senderId,
      Value<Uint8List>? payload,
      Value<Uint8List?>? plaintextCache,
      Value<DateTime>? createdAt,
      Value<bool>? isDelivered,
      Value<int>? rowid}) {
    return MessagesTableCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      payload: payload ?? this.payload,
      plaintextCache: plaintextCache ?? this.plaintextCache,
      createdAt: createdAt ?? this.createdAt,
      isDelivered: isDelivered ?? this.isDelivered,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (plaintextCache.present) {
      map['plaintext_cache'] = Variable<Uint8List>(plaintextCache.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDelivered.present) {
      map['is_delivered'] = Variable<bool>(isDelivered.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesTableCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderId: $senderId, ')
          ..write('payload: $payload, ')
          ..write('plaintextCache: $plaintextCache, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDelivered: $isDelivered, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ForumPostsTableTable extends ForumPostsTable
    with TableInfo<$ForumPostsTableTable, ForumPostsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ForumPostsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorIdMeta =
      const VerificationMeta('authorId');
  @override
  late final GeneratedColumn<String> authorId = GeneratedColumn<String>(
      'author_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
      'payload', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _resolvedMeta =
      const VerificationMeta('resolved');
  @override
  late final GeneratedColumn<bool> resolved = GeneratedColumn<bool>(
      'resolved', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("resolved" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, authorId, title, payload, resolved, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'forum_posts_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<ForumPostsTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('author_id')) {
      context.handle(_authorIdMeta,
          authorId.isAcceptableOrUnknown(data['author_id']!, _authorIdMeta));
    } else if (isInserting) {
      context.missing(_authorIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('resolved')) {
      context.handle(_resolvedMeta,
          resolved.isAcceptableOrUnknown(data['resolved']!, _resolvedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ForumPostsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ForumPostsTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      authorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}payload'])!,
      resolved: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}resolved'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ForumPostsTableTable createAlias(String alias) {
    return $ForumPostsTableTable(attachedDatabase, alias);
  }
}

class ForumPostsTableData extends DataClass
    implements Insertable<ForumPostsTableData> {
  final String id;
  final String authorId;
  final String title;
  final Uint8List payload;
  final bool resolved;
  final DateTime createdAt;
  const ForumPostsTableData(
      {required this.id,
      required this.authorId,
      required this.title,
      required this.payload,
      required this.resolved,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['author_id'] = Variable<String>(authorId);
    map['title'] = Variable<String>(title);
    map['payload'] = Variable<Uint8List>(payload);
    map['resolved'] = Variable<bool>(resolved);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ForumPostsTableCompanion toCompanion(bool nullToAbsent) {
    return ForumPostsTableCompanion(
      id: Value(id),
      authorId: Value(authorId),
      title: Value(title),
      payload: Value(payload),
      resolved: Value(resolved),
      createdAt: Value(createdAt),
    );
  }

  factory ForumPostsTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ForumPostsTableData(
      id: serializer.fromJson<String>(json['id']),
      authorId: serializer.fromJson<String>(json['authorId']),
      title: serializer.fromJson<String>(json['title']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      resolved: serializer.fromJson<bool>(json['resolved']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'authorId': serializer.toJson<String>(authorId),
      'title': serializer.toJson<String>(title),
      'payload': serializer.toJson<Uint8List>(payload),
      'resolved': serializer.toJson<bool>(resolved),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ForumPostsTableData copyWith(
          {String? id,
          String? authorId,
          String? title,
          Uint8List? payload,
          bool? resolved,
          DateTime? createdAt}) =>
      ForumPostsTableData(
        id: id ?? this.id,
        authorId: authorId ?? this.authorId,
        title: title ?? this.title,
        payload: payload ?? this.payload,
        resolved: resolved ?? this.resolved,
        createdAt: createdAt ?? this.createdAt,
      );
  @override
  String toString() {
    return (StringBuffer('ForumPostsTableData(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('title: $title, ')
          ..write('payload: $payload, ')
          ..write('resolved: $resolved, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, authorId, title,
      $driftBlobEquality.hash(payload), resolved, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ForumPostsTableData &&
          other.id == this.id &&
          other.authorId == this.authorId &&
          other.title == this.title &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.resolved == this.resolved &&
          other.createdAt == this.createdAt);
}

class ForumPostsTableCompanion extends UpdateCompanion<ForumPostsTableData> {
  final Value<String> id;
  final Value<String> authorId;
  final Value<String> title;
  final Value<Uint8List> payload;
  final Value<bool> resolved;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ForumPostsTableCompanion({
    this.id = const Value.absent(),
    this.authorId = const Value.absent(),
    this.title = const Value.absent(),
    this.payload = const Value.absent(),
    this.resolved = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ForumPostsTableCompanion.insert({
    required String id,
    required String authorId,
    required String title,
    required Uint8List payload,
    this.resolved = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        authorId = Value(authorId),
        title = Value(title),
        payload = Value(payload),
        createdAt = Value(createdAt);
  static Insertable<ForumPostsTableData> custom({
    Expression<String>? id,
    Expression<String>? authorId,
    Expression<String>? title,
    Expression<Uint8List>? payload,
    Expression<bool>? resolved,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorId != null) 'author_id': authorId,
      if (title != null) 'title': title,
      if (payload != null) 'payload': payload,
      if (resolved != null) 'resolved': resolved,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ForumPostsTableCompanion copyWith(
      {Value<String>? id,
      Value<String>? authorId,
      Value<String>? title,
      Value<Uint8List>? payload,
      Value<bool>? resolved,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ForumPostsTableCompanion(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      payload: payload ?? this.payload,
      resolved: resolved ?? this.resolved,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (authorId.present) {
      map['author_id'] = Variable<String>(authorId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (resolved.present) {
      map['resolved'] = Variable<bool>(resolved.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ForumPostsTableCompanion(')
          ..write('id: $id, ')
          ..write('authorId: $authorId, ')
          ..write('title: $title, ')
          ..write('payload: $payload, ')
          ..write('resolved: $resolved, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTableTable extends UserProfilesTable
    with TableInfo<$UserProfilesTableTable, UserProfilesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillsJsonMeta =
      const VerificationMeta('skillsJson');
  @override
  late final GeneratedColumn<String> skillsJson = GeneratedColumn<String>(
      'skills_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _availabilityMeta =
      const VerificationMeta('availability');
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
      'availability', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('online'));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, displayName, skillsJson, availability, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<UserProfilesTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('skills_json')) {
      context.handle(
          _skillsJsonMeta,
          skillsJson.isAcceptableOrUnknown(
              data['skills_json']!, _skillsJsonMeta));
    }
    if (data.containsKey('availability')) {
      context.handle(
          _availabilityMeta,
          availability.isAcceptableOrUnknown(
              data['availability']!, _availabilityMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  UserProfilesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfilesTableData(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name'])!,
      skillsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skills_json'])!,
      availability: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}availability'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserProfilesTableTable createAlias(String alias) {
    return $UserProfilesTableTable(attachedDatabase, alias);
  }
}

class UserProfilesTableData extends DataClass
    implements Insertable<UserProfilesTableData> {
  final String userId;
  final String displayName;
  final String skillsJson;
  final String availability;
  final DateTime updatedAt;
  const UserProfilesTableData(
      {required this.userId,
      required this.displayName,
      required this.skillsJson,
      required this.availability,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['display_name'] = Variable<String>(displayName);
    map['skills_json'] = Variable<String>(skillsJson);
    map['availability'] = Variable<String>(availability);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesTableCompanion(
      userId: Value(userId),
      displayName: Value(displayName),
      skillsJson: Value(skillsJson),
      availability: Value(availability),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfilesTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfilesTableData(
      userId: serializer.fromJson<String>(json['userId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      skillsJson: serializer.fromJson<String>(json['skillsJson']),
      availability: serializer.fromJson<String>(json['availability']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'displayName': serializer.toJson<String>(displayName),
      'skillsJson': serializer.toJson<String>(skillsJson),
      'availability': serializer.toJson<String>(availability),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfilesTableData copyWith(
          {String? userId,
          String? displayName,
          String? skillsJson,
          String? availability,
          DateTime? updatedAt}) =>
      UserProfilesTableData(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        skillsJson: skillsJson ?? this.skillsJson,
        availability: availability ?? this.availability,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('UserProfilesTableData(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('skillsJson: $skillsJson, ')
          ..write('availability: $availability, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(userId, displayName, skillsJson, availability, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfilesTableData &&
          other.userId == this.userId &&
          other.displayName == this.displayName &&
          other.skillsJson == this.skillsJson &&
          other.availability == this.availability &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesTableCompanion
    extends UpdateCompanion<UserProfilesTableData> {
  final Value<String> userId;
  final Value<String> displayName;
  final Value<String> skillsJson;
  final Value<String> availability;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProfilesTableCompanion({
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.skillsJson = const Value.absent(),
    this.availability = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesTableCompanion.insert({
    required String userId,
    required String displayName,
    this.skillsJson = const Value.absent(),
    this.availability = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        displayName = Value(displayName),
        updatedAt = Value(updatedAt);
  static Insertable<UserProfilesTableData> custom({
    Expression<String>? userId,
    Expression<String>? displayName,
    Expression<String>? skillsJson,
    Expression<String>? availability,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (skillsJson != null) 'skills_json': skillsJson,
      if (availability != null) 'availability': availability,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesTableCompanion copyWith(
      {Value<String>? userId,
      Value<String>? displayName,
      Value<String>? skillsJson,
      Value<String>? availability,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UserProfilesTableCompanion(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      skillsJson: skillsJson ?? this.skillsJson,
      availability: availability ?? this.availability,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (skillsJson.present) {
      map['skills_json'] = Variable<String>(skillsJson.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesTableCompanion(')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('skillsJson: $skillsJson, ')
          ..write('availability: $availability, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboundQueueTableTable extends OutboundQueueTable
    with TableInfo<$OutboundQueueTableTable, OutboundQueueTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboundQueueTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  @override
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
      'to_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
      'payload', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _queuedAtMeta =
      const VerificationMeta('queuedAt');
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
      'queued_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [id, toId, payload, queuedAt, attempts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbound_queue_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<OutboundQueueTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('to_id')) {
      context.handle(
          _toIdMeta, toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta));
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(_queuedAtMeta,
          queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta));
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboundQueueTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboundQueueTableData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      toId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}to_id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}payload'])!,
      queuedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}queued_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
    );
  }

  @override
  $OutboundQueueTableTable createAlias(String alias) {
    return $OutboundQueueTableTable(attachedDatabase, alias);
  }
}

class OutboundQueueTableData extends DataClass
    implements Insertable<OutboundQueueTableData> {
  final int id;
  final String toId;
  final Uint8List payload;
  final DateTime queuedAt;
  final int attempts;
  const OutboundQueueTableData(
      {required this.id,
      required this.toId,
      required this.payload,
      required this.queuedAt,
      required this.attempts});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['to_id'] = Variable<String>(toId);
    map['payload'] = Variable<Uint8List>(payload);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  OutboundQueueTableCompanion toCompanion(bool nullToAbsent) {
    return OutboundQueueTableCompanion(
      id: Value(id),
      toId: Value(toId),
      payload: Value(payload),
      queuedAt: Value(queuedAt),
      attempts: Value(attempts),
    );
  }

  factory OutboundQueueTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboundQueueTableData(
      id: serializer.fromJson<int>(json['id']),
      toId: serializer.fromJson<String>(json['toId']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'toId': serializer.toJson<String>(toId),
      'payload': serializer.toJson<Uint8List>(payload),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  OutboundQueueTableData copyWith(
          {int? id,
          String? toId,
          Uint8List? payload,
          DateTime? queuedAt,
          int? attempts}) =>
      OutboundQueueTableData(
        id: id ?? this.id,
        toId: toId ?? this.toId,
        payload: payload ?? this.payload,
        queuedAt: queuedAt ?? this.queuedAt,
        attempts: attempts ?? this.attempts,
      );
  @override
  String toString() {
    return (StringBuffer('OutboundQueueTableData(')
          ..write('id: $id, ')
          ..write('toId: $toId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, toId, $driftBlobEquality.hash(payload), queuedAt, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboundQueueTableData &&
          other.id == this.id &&
          other.toId == this.toId &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.queuedAt == this.queuedAt &&
          other.attempts == this.attempts);
}

class OutboundQueueTableCompanion
    extends UpdateCompanion<OutboundQueueTableData> {
  final Value<int> id;
  final Value<String> toId;
  final Value<Uint8List> payload;
  final Value<DateTime> queuedAt;
  final Value<int> attempts;
  const OutboundQueueTableCompanion({
    this.id = const Value.absent(),
    this.toId = const Value.absent(),
    this.payload = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  OutboundQueueTableCompanion.insert({
    this.id = const Value.absent(),
    required String toId,
    required Uint8List payload,
    required DateTime queuedAt,
    this.attempts = const Value.absent(),
  })  : toId = Value(toId),
        payload = Value(payload),
        queuedAt = Value(queuedAt);
  static Insertable<OutboundQueueTableData> custom({
    Expression<int>? id,
    Expression<String>? toId,
    Expression<Uint8List>? payload,
    Expression<DateTime>? queuedAt,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (toId != null) 'to_id': toId,
      if (payload != null) 'payload': payload,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (attempts != null) 'attempts': attempts,
    });
  }

  OutboundQueueTableCompanion copyWith(
      {Value<int>? id,
      Value<String>? toId,
      Value<Uint8List>? payload,
      Value<DateTime>? queuedAt,
      Value<int>? attempts}) {
    return OutboundQueueTableCompanion(
      id: id ?? this.id,
      toId: toId ?? this.toId,
      payload: payload ?? this.payload,
      queuedAt: queuedAt ?? this.queuedAt,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboundQueueTableCompanion(')
          ..write('id: $id, ')
          ..write('toId: $toId, ')
          ..write('payload: $payload, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

class $MlsGroupStateTableTable extends MlsGroupStateTable
    with TableInfo<$MlsGroupStateTableTable, MlsGroupStateTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MlsGroupStateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _stateDataMeta =
      const VerificationMeta('stateData');
  @override
  late final GeneratedColumn<Uint8List> stateData = GeneratedColumn<Uint8List>(
      'state_data', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
      'epoch', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [groupId, stateData, epoch, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mls_group_state_table';
  @override
  VerificationContext validateIntegrity(
      Insertable<MlsGroupStateTableData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('state_data')) {
      context.handle(_stateDataMeta,
          stateData.isAcceptableOrUnknown(data['state_data']!, _stateDataMeta));
    } else if (isInserting) {
      context.missing(_stateDataMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
          _epochMeta, epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId};
  @override
  MlsGroupStateTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MlsGroupStateTableData(
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      stateData: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}state_data'])!,
      epoch: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}epoch'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MlsGroupStateTableTable createAlias(String alias) {
    return $MlsGroupStateTableTable(attachedDatabase, alias);
  }
}

class MlsGroupStateTableData extends DataClass
    implements Insertable<MlsGroupStateTableData> {
  final String groupId;
  final Uint8List stateData;
  final int epoch;
  final DateTime updatedAt;
  const MlsGroupStateTableData(
      {required this.groupId,
      required this.stateData,
      required this.epoch,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['state_data'] = Variable<Uint8List>(stateData);
    map['epoch'] = Variable<int>(epoch);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MlsGroupStateTableCompanion toCompanion(bool nullToAbsent) {
    return MlsGroupStateTableCompanion(
      groupId: Value(groupId),
      stateData: Value(stateData),
      epoch: Value(epoch),
      updatedAt: Value(updatedAt),
    );
  }

  factory MlsGroupStateTableData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MlsGroupStateTableData(
      groupId: serializer.fromJson<String>(json['groupId']),
      stateData: serializer.fromJson<Uint8List>(json['stateData']),
      epoch: serializer.fromJson<int>(json['epoch']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'stateData': serializer.toJson<Uint8List>(stateData),
      'epoch': serializer.toJson<int>(epoch),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MlsGroupStateTableData copyWith(
          {String? groupId,
          Uint8List? stateData,
          int? epoch,
          DateTime? updatedAt}) =>
      MlsGroupStateTableData(
        groupId: groupId ?? this.groupId,
        stateData: stateData ?? this.stateData,
        epoch: epoch ?? this.epoch,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  @override
  String toString() {
    return (StringBuffer('MlsGroupStateTableData(')
          ..write('groupId: $groupId, ')
          ..write('stateData: $stateData, ')
          ..write('epoch: $epoch, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      groupId, $driftBlobEquality.hash(stateData), epoch, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MlsGroupStateTableData &&
          other.groupId == this.groupId &&
          $driftBlobEquality.equals(other.stateData, this.stateData) &&
          other.epoch == this.epoch &&
          other.updatedAt == this.updatedAt);
}

class MlsGroupStateTableCompanion
    extends UpdateCompanion<MlsGroupStateTableData> {
  final Value<String> groupId;
  final Value<Uint8List> stateData;
  final Value<int> epoch;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MlsGroupStateTableCompanion({
    this.groupId = const Value.absent(),
    this.stateData = const Value.absent(),
    this.epoch = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MlsGroupStateTableCompanion.insert({
    required String groupId,
    required Uint8List stateData,
    this.epoch = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : groupId = Value(groupId),
        stateData = Value(stateData);
  static Insertable<MlsGroupStateTableData> custom({
    Expression<String>? groupId,
    Expression<Uint8List>? stateData,
    Expression<int>? epoch,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (stateData != null) 'state_data': stateData,
      if (epoch != null) 'epoch': epoch,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MlsGroupStateTableCompanion copyWith(
      {Value<String>? groupId,
      Value<Uint8List>? stateData,
      Value<int>? epoch,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return MlsGroupStateTableCompanion(
      groupId: groupId ?? this.groupId,
      stateData: stateData ?? this.stateData,
      epoch: epoch ?? this.epoch,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (stateData.present) {
      map['state_data'] = Variable<Uint8List>(stateData.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MlsGroupStateTableCompanion(')
          ..write('groupId: $groupId, ')
          ..write('stateData: $stateData, ')
          ..write('epoch: $epoch, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $ContactsTableTable contactsTable = $ContactsTableTable(this);
  late final $MessagesTableTable messagesTable = $MessagesTableTable(this);
  late final $ForumPostsTableTable forumPostsTable =
      $ForumPostsTableTable(this);
  late final $UserProfilesTableTable userProfilesTable =
      $UserProfilesTableTable(this);
  late final $OutboundQueueTableTable outboundQueueTable =
      $OutboundQueueTableTable(this);
  late final $MlsGroupStateTableTable mlsGroupStateTable =
      $MlsGroupStateTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        contactsTable,
        messagesTable,
        forumPostsTable,
        userProfilesTable,
        outboundQueueTable,
        mlsGroupStateTable
      ];
}
