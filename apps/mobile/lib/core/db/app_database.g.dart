// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalSessionsTable extends LocalSessions
    with TableInfo<$LocalSessionsTable, LocalSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientSessionIdMeta =
      const VerificationMeta('clientSessionId');
  @override
  late final GeneratedColumn<String> clientSessionId = GeneratedColumn<String>(
      'client_session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programIdMeta =
      const VerificationMeta('programId');
  @override
  late final GeneratedColumn<String> programId = GeneratedColumn<String>(
      'program_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _programDayIdMeta =
      const VerificationMeta('programDayId');
  @override
  late final GeneratedColumn<String> programDayId = GeneratedColumn<String>(
      'program_day_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
      'started_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<String> completedAt = GeneratedColumn<String>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _snapshotJsonMeta =
      const VerificationMeta('snapshotJson');
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
      'snapshot_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientSessionId,
        serverId,
        status,
        name,
        programId,
        programDayId,
        startedAt,
        completedAt,
        notes,
        snapshotJson,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_session_id')) {
      context.handle(
          _clientSessionIdMeta,
          clientSessionId.isAcceptableOrUnknown(
              data['client_session_id']!, _clientSessionIdMeta));
    } else if (isInserting) {
      context.missing(_clientSessionIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('program_id')) {
      context.handle(_programIdMeta,
          programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta));
    }
    if (data.containsKey('program_day_id')) {
      context.handle(
          _programDayIdMeta,
          programDayId.isAcceptableOrUnknown(
              data['program_day_id']!, _programDayIdMeta));
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
          _snapshotJsonMeta,
          snapshotJson.isAcceptableOrUnknown(
              data['snapshot_json']!, _snapshotJsonMeta));
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {clientSessionId};
  @override
  LocalSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSession(
      clientSessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_session_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      programId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program_id']),
      programDayId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}program_day_id']),
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_at'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}completed_at']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      snapshotJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}snapshot_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $LocalSessionsTable createAlias(String alias) {
    return $LocalSessionsTable(attachedDatabase, alias);
  }
}

class LocalSession extends DataClass implements Insertable<LocalSession> {
  final String clientSessionId;
  final String? serverId;
  final String status;
  final String name;
  final String? programId;
  final String? programDayId;
  final String startedAt;
  final String? completedAt;
  final String? notes;

  /// The server's last answer (or the offline seed), as JSON: targets,
  /// last performance and the summary live here, not in columns.
  final String snapshotJson;
  final String updatedAt;
  const LocalSession(
      {required this.clientSessionId,
      this.serverId,
      required this.status,
      required this.name,
      this.programId,
      this.programDayId,
      required this.startedAt,
      this.completedAt,
      this.notes,
      required this.snapshotJson,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_session_id'] = Variable<String>(clientSessionId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['status'] = Variable<String>(status);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || programId != null) {
      map['program_id'] = Variable<String>(programId);
    }
    if (!nullToAbsent || programDayId != null) {
      map['program_day_id'] = Variable<String>(programDayId);
    }
    map['started_at'] = Variable<String>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<String>(completedAt);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['snapshot_json'] = Variable<String>(snapshotJson);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  LocalSessionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSessionsCompanion(
      clientSessionId: Value(clientSessionId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      status: Value(status),
      name: Value(name),
      programId: programId == null && nullToAbsent
          ? const Value.absent()
          : Value(programId),
      programDayId: programDayId == null && nullToAbsent
          ? const Value.absent()
          : Value(programDayId),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      snapshotJson: Value(snapshotJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSession(
      clientSessionId: serializer.fromJson<String>(json['clientSessionId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      status: serializer.fromJson<String>(json['status']),
      name: serializer.fromJson<String>(json['name']),
      programId: serializer.fromJson<String?>(json['programId']),
      programDayId: serializer.fromJson<String?>(json['programDayId']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      completedAt: serializer.fromJson<String?>(json['completedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientSessionId': serializer.toJson<String>(clientSessionId),
      'serverId': serializer.toJson<String?>(serverId),
      'status': serializer.toJson<String>(status),
      'name': serializer.toJson<String>(name),
      'programId': serializer.toJson<String?>(programId),
      'programDayId': serializer.toJson<String?>(programDayId),
      'startedAt': serializer.toJson<String>(startedAt),
      'completedAt': serializer.toJson<String?>(completedAt),
      'notes': serializer.toJson<String?>(notes),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  LocalSession copyWith(
          {String? clientSessionId,
          Value<String?> serverId = const Value.absent(),
          String? status,
          String? name,
          Value<String?> programId = const Value.absent(),
          Value<String?> programDayId = const Value.absent(),
          String? startedAt,
          Value<String?> completedAt = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          String? snapshotJson,
          String? updatedAt}) =>
      LocalSession(
        clientSessionId: clientSessionId ?? this.clientSessionId,
        serverId: serverId.present ? serverId.value : this.serverId,
        status: status ?? this.status,
        name: name ?? this.name,
        programId: programId.present ? programId.value : this.programId,
        programDayId:
            programDayId.present ? programDayId.value : this.programDayId,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        notes: notes.present ? notes.value : this.notes,
        snapshotJson: snapshotJson ?? this.snapshotJson,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocalSession copyWithCompanion(LocalSessionsCompanion data) {
    return LocalSession(
      clientSessionId: data.clientSessionId.present
          ? data.clientSessionId.value
          : this.clientSessionId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      status: data.status.present ? data.status.value : this.status,
      name: data.name.present ? data.name.value : this.name,
      programId: data.programId.present ? data.programId.value : this.programId,
      programDayId: data.programDayId.present
          ? data.programDayId.value
          : this.programDayId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSession(')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('serverId: $serverId, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('programId: $programId, ')
          ..write('programDayId: $programDayId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('notes: $notes, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientSessionId,
      serverId,
      status,
      name,
      programId,
      programDayId,
      startedAt,
      completedAt,
      notes,
      snapshotJson,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSession &&
          other.clientSessionId == this.clientSessionId &&
          other.serverId == this.serverId &&
          other.status == this.status &&
          other.name == this.name &&
          other.programId == this.programId &&
          other.programDayId == this.programDayId &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.notes == this.notes &&
          other.snapshotJson == this.snapshotJson &&
          other.updatedAt == this.updatedAt);
}

class LocalSessionsCompanion extends UpdateCompanion<LocalSession> {
  final Value<String> clientSessionId;
  final Value<String?> serverId;
  final Value<String> status;
  final Value<String> name;
  final Value<String?> programId;
  final Value<String?> programDayId;
  final Value<String> startedAt;
  final Value<String?> completedAt;
  final Value<String?> notes;
  final Value<String> snapshotJson;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const LocalSessionsCompanion({
    this.clientSessionId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.status = const Value.absent(),
    this.name = const Value.absent(),
    this.programId = const Value.absent(),
    this.programDayId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSessionsCompanion.insert({
    required String clientSessionId,
    this.serverId = const Value.absent(),
    required String status,
    required String name,
    this.programId = const Value.absent(),
    this.programDayId = const Value.absent(),
    required String startedAt,
    this.completedAt = const Value.absent(),
    this.notes = const Value.absent(),
    required String snapshotJson,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : clientSessionId = Value(clientSessionId),
        status = Value(status),
        name = Value(name),
        startedAt = Value(startedAt),
        snapshotJson = Value(snapshotJson),
        updatedAt = Value(updatedAt);
  static Insertable<LocalSession> custom({
    Expression<String>? clientSessionId,
    Expression<String>? serverId,
    Expression<String>? status,
    Expression<String>? name,
    Expression<String>? programId,
    Expression<String>? programDayId,
    Expression<String>? startedAt,
    Expression<String>? completedAt,
    Expression<String>? notes,
    Expression<String>? snapshotJson,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientSessionId != null) 'client_session_id': clientSessionId,
      if (serverId != null) 'server_id': serverId,
      if (status != null) 'status': status,
      if (name != null) 'name': name,
      if (programId != null) 'program_id': programId,
      if (programDayId != null) 'program_day_id': programDayId,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (notes != null) 'notes': notes,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSessionsCompanion copyWith(
      {Value<String>? clientSessionId,
      Value<String?>? serverId,
      Value<String>? status,
      Value<String>? name,
      Value<String?>? programId,
      Value<String?>? programDayId,
      Value<String>? startedAt,
      Value<String?>? completedAt,
      Value<String?>? notes,
      Value<String>? snapshotJson,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return LocalSessionsCompanion(
      clientSessionId: clientSessionId ?? this.clientSessionId,
      serverId: serverId ?? this.serverId,
      status: status ?? this.status,
      name: name ?? this.name,
      programId: programId ?? this.programId,
      programDayId: programDayId ?? this.programDayId,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientSessionId.present) {
      map['client_session_id'] = Variable<String>(clientSessionId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<String>(programId.value);
    }
    if (programDayId.present) {
      map['program_day_id'] = Variable<String>(programDayId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<String>(completedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionsCompanion(')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('serverId: $serverId, ')
          ..write('status: $status, ')
          ..write('name: $name, ')
          ..write('programId: $programId, ')
          ..write('programDayId: $programDayId, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('notes: $notes, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSessionExercisesTable extends LocalSessionExercises
    with TableInfo<$LocalSessionExercisesTable, LocalSessionExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSessionExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientExerciseIdMeta =
      const VerificationMeta('clientExerciseId');
  @override
  late final GeneratedColumn<String> clientExerciseId = GeneratedColumn<String>(
      'client_exercise_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientSessionIdMeta =
      const VerificationMeta('clientSessionId');
  @override
  late final GeneratedColumn<String> clientSessionId = GeneratedColumn<String>(
      'client_session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exerciseIdMeta =
      const VerificationMeta('exerciseId');
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
      'exercise_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plannedExerciseIdMeta =
      const VerificationMeta('plannedExerciseId');
  @override
  late final GeneratedColumn<String> plannedExerciseId =
      GeneratedColumn<String>('planned_exercise_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _orderIndexMeta =
      const VerificationMeta('orderIndex');
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
      'order_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _supersetGroupMeta =
      const VerificationMeta('supersetGroup');
  @override
  late final GeneratedColumn<int> supersetGroup = GeneratedColumn<int>(
      'superset_group', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _removedMeta =
      const VerificationMeta('removed');
  @override
  late final GeneratedColumn<bool> removed = GeneratedColumn<bool>(
      'removed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("removed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _exerciseJsonMeta =
      const VerificationMeta('exerciseJson');
  @override
  late final GeneratedColumn<String> exerciseJson = GeneratedColumn<String>(
      'exercise_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientExerciseId,
        clientSessionId,
        serverId,
        exerciseId,
        plannedExerciseId,
        orderIndex,
        supersetGroup,
        removed,
        exerciseJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_session_exercises';
  @override
  VerificationContext validateIntegrity(
      Insertable<LocalSessionExercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_exercise_id')) {
      context.handle(
          _clientExerciseIdMeta,
          clientExerciseId.isAcceptableOrUnknown(
              data['client_exercise_id']!, _clientExerciseIdMeta));
    } else if (isInserting) {
      context.missing(_clientExerciseIdMeta);
    }
    if (data.containsKey('client_session_id')) {
      context.handle(
          _clientSessionIdMeta,
          clientSessionId.isAcceptableOrUnknown(
              data['client_session_id']!, _clientSessionIdMeta));
    } else if (isInserting) {
      context.missing(_clientSessionIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
          _exerciseIdMeta,
          exerciseId.isAcceptableOrUnknown(
              data['exercise_id']!, _exerciseIdMeta));
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('planned_exercise_id')) {
      context.handle(
          _plannedExerciseIdMeta,
          plannedExerciseId.isAcceptableOrUnknown(
              data['planned_exercise_id']!, _plannedExerciseIdMeta));
    }
    if (data.containsKey('order_index')) {
      context.handle(
          _orderIndexMeta,
          orderIndex.isAcceptableOrUnknown(
              data['order_index']!, _orderIndexMeta));
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('superset_group')) {
      context.handle(
          _supersetGroupMeta,
          supersetGroup.isAcceptableOrUnknown(
              data['superset_group']!, _supersetGroupMeta));
    }
    if (data.containsKey('removed')) {
      context.handle(_removedMeta,
          removed.isAcceptableOrUnknown(data['removed']!, _removedMeta));
    }
    if (data.containsKey('exercise_json')) {
      context.handle(
          _exerciseJsonMeta,
          exerciseJson.isAcceptableOrUnknown(
              data['exercise_json']!, _exerciseJsonMeta));
    } else if (isInserting) {
      context.missing(_exerciseJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientExerciseId};
  @override
  LocalSessionExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSessionExercise(
      clientExerciseId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_exercise_id'])!,
      clientSessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_session_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      exerciseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_id'])!,
      plannedExerciseId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}planned_exercise_id']),
      orderIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order_index'])!,
      supersetGroup: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}superset_group']),
      removed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}removed'])!,
      exerciseJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_json'])!,
    );
  }

  @override
  $LocalSessionExercisesTable createAlias(String alias) {
    return $LocalSessionExercisesTable(attachedDatabase, alias);
  }
}

class LocalSessionExercise extends DataClass
    implements Insertable<LocalSessionExercise> {
  final String clientExerciseId;
  final String clientSessionId;
  final String? serverId;
  final String exerciseId;
  final String? plannedExerciseId;
  final int orderIndex;
  final int? supersetGroup;
  final bool removed;

  /// Catalogue metadata + targets + last performance, as JSON.
  final String exerciseJson;
  const LocalSessionExercise(
      {required this.clientExerciseId,
      required this.clientSessionId,
      this.serverId,
      required this.exerciseId,
      this.plannedExerciseId,
      required this.orderIndex,
      this.supersetGroup,
      required this.removed,
      required this.exerciseJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_exercise_id'] = Variable<String>(clientExerciseId);
    map['client_session_id'] = Variable<String>(clientSessionId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['exercise_id'] = Variable<String>(exerciseId);
    if (!nullToAbsent || plannedExerciseId != null) {
      map['planned_exercise_id'] = Variable<String>(plannedExerciseId);
    }
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || supersetGroup != null) {
      map['superset_group'] = Variable<int>(supersetGroup);
    }
    map['removed'] = Variable<bool>(removed);
    map['exercise_json'] = Variable<String>(exerciseJson);
    return map;
  }

  LocalSessionExercisesCompanion toCompanion(bool nullToAbsent) {
    return LocalSessionExercisesCompanion(
      clientExerciseId: Value(clientExerciseId),
      clientSessionId: Value(clientSessionId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      exerciseId: Value(exerciseId),
      plannedExerciseId: plannedExerciseId == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedExerciseId),
      orderIndex: Value(orderIndex),
      supersetGroup: supersetGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(supersetGroup),
      removed: Value(removed),
      exerciseJson: Value(exerciseJson),
    );
  }

  factory LocalSessionExercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSessionExercise(
      clientExerciseId: serializer.fromJson<String>(json['clientExerciseId']),
      clientSessionId: serializer.fromJson<String>(json['clientSessionId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      plannedExerciseId:
          serializer.fromJson<String?>(json['plannedExerciseId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      supersetGroup: serializer.fromJson<int?>(json['supersetGroup']),
      removed: serializer.fromJson<bool>(json['removed']),
      exerciseJson: serializer.fromJson<String>(json['exerciseJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientExerciseId': serializer.toJson<String>(clientExerciseId),
      'clientSessionId': serializer.toJson<String>(clientSessionId),
      'serverId': serializer.toJson<String?>(serverId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'plannedExerciseId': serializer.toJson<String?>(plannedExerciseId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'supersetGroup': serializer.toJson<int?>(supersetGroup),
      'removed': serializer.toJson<bool>(removed),
      'exerciseJson': serializer.toJson<String>(exerciseJson),
    };
  }

  LocalSessionExercise copyWith(
          {String? clientExerciseId,
          String? clientSessionId,
          Value<String?> serverId = const Value.absent(),
          String? exerciseId,
          Value<String?> plannedExerciseId = const Value.absent(),
          int? orderIndex,
          Value<int?> supersetGroup = const Value.absent(),
          bool? removed,
          String? exerciseJson}) =>
      LocalSessionExercise(
        clientExerciseId: clientExerciseId ?? this.clientExerciseId,
        clientSessionId: clientSessionId ?? this.clientSessionId,
        serverId: serverId.present ? serverId.value : this.serverId,
        exerciseId: exerciseId ?? this.exerciseId,
        plannedExerciseId: plannedExerciseId.present
            ? plannedExerciseId.value
            : this.plannedExerciseId,
        orderIndex: orderIndex ?? this.orderIndex,
        supersetGroup:
            supersetGroup.present ? supersetGroup.value : this.supersetGroup,
        removed: removed ?? this.removed,
        exerciseJson: exerciseJson ?? this.exerciseJson,
      );
  LocalSessionExercise copyWithCompanion(LocalSessionExercisesCompanion data) {
    return LocalSessionExercise(
      clientExerciseId: data.clientExerciseId.present
          ? data.clientExerciseId.value
          : this.clientExerciseId,
      clientSessionId: data.clientSessionId.present
          ? data.clientSessionId.value
          : this.clientSessionId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      plannedExerciseId: data.plannedExerciseId.present
          ? data.plannedExerciseId.value
          : this.plannedExerciseId,
      orderIndex:
          data.orderIndex.present ? data.orderIndex.value : this.orderIndex,
      supersetGroup: data.supersetGroup.present
          ? data.supersetGroup.value
          : this.supersetGroup,
      removed: data.removed.present ? data.removed.value : this.removed,
      exerciseJson: data.exerciseJson.present
          ? data.exerciseJson.value
          : this.exerciseJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionExercise(')
          ..write('clientExerciseId: $clientExerciseId, ')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('serverId: $serverId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('plannedExerciseId: $plannedExerciseId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('removed: $removed, ')
          ..write('exerciseJson: $exerciseJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientExerciseId,
      clientSessionId,
      serverId,
      exerciseId,
      plannedExerciseId,
      orderIndex,
      supersetGroup,
      removed,
      exerciseJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSessionExercise &&
          other.clientExerciseId == this.clientExerciseId &&
          other.clientSessionId == this.clientSessionId &&
          other.serverId == this.serverId &&
          other.exerciseId == this.exerciseId &&
          other.plannedExerciseId == this.plannedExerciseId &&
          other.orderIndex == this.orderIndex &&
          other.supersetGroup == this.supersetGroup &&
          other.removed == this.removed &&
          other.exerciseJson == this.exerciseJson);
}

class LocalSessionExercisesCompanion
    extends UpdateCompanion<LocalSessionExercise> {
  final Value<String> clientExerciseId;
  final Value<String> clientSessionId;
  final Value<String?> serverId;
  final Value<String> exerciseId;
  final Value<String?> plannedExerciseId;
  final Value<int> orderIndex;
  final Value<int?> supersetGroup;
  final Value<bool> removed;
  final Value<String> exerciseJson;
  final Value<int> rowid;
  const LocalSessionExercisesCompanion({
    this.clientExerciseId = const Value.absent(),
    this.clientSessionId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.plannedExerciseId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.supersetGroup = const Value.absent(),
    this.removed = const Value.absent(),
    this.exerciseJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSessionExercisesCompanion.insert({
    required String clientExerciseId,
    required String clientSessionId,
    this.serverId = const Value.absent(),
    required String exerciseId,
    this.plannedExerciseId = const Value.absent(),
    required int orderIndex,
    this.supersetGroup = const Value.absent(),
    this.removed = const Value.absent(),
    required String exerciseJson,
    this.rowid = const Value.absent(),
  })  : clientExerciseId = Value(clientExerciseId),
        clientSessionId = Value(clientSessionId),
        exerciseId = Value(exerciseId),
        orderIndex = Value(orderIndex),
        exerciseJson = Value(exerciseJson);
  static Insertable<LocalSessionExercise> custom({
    Expression<String>? clientExerciseId,
    Expression<String>? clientSessionId,
    Expression<String>? serverId,
    Expression<String>? exerciseId,
    Expression<String>? plannedExerciseId,
    Expression<int>? orderIndex,
    Expression<int>? supersetGroup,
    Expression<bool>? removed,
    Expression<String>? exerciseJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientExerciseId != null) 'client_exercise_id': clientExerciseId,
      if (clientSessionId != null) 'client_session_id': clientSessionId,
      if (serverId != null) 'server_id': serverId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (plannedExerciseId != null) 'planned_exercise_id': plannedExerciseId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (supersetGroup != null) 'superset_group': supersetGroup,
      if (removed != null) 'removed': removed,
      if (exerciseJson != null) 'exercise_json': exerciseJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSessionExercisesCompanion copyWith(
      {Value<String>? clientExerciseId,
      Value<String>? clientSessionId,
      Value<String?>? serverId,
      Value<String>? exerciseId,
      Value<String?>? plannedExerciseId,
      Value<int>? orderIndex,
      Value<int?>? supersetGroup,
      Value<bool>? removed,
      Value<String>? exerciseJson,
      Value<int>? rowid}) {
    return LocalSessionExercisesCompanion(
      clientExerciseId: clientExerciseId ?? this.clientExerciseId,
      clientSessionId: clientSessionId ?? this.clientSessionId,
      serverId: serverId ?? this.serverId,
      exerciseId: exerciseId ?? this.exerciseId,
      plannedExerciseId: plannedExerciseId ?? this.plannedExerciseId,
      orderIndex: orderIndex ?? this.orderIndex,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      removed: removed ?? this.removed,
      exerciseJson: exerciseJson ?? this.exerciseJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientExerciseId.present) {
      map['client_exercise_id'] = Variable<String>(clientExerciseId.value);
    }
    if (clientSessionId.present) {
      map['client_session_id'] = Variable<String>(clientSessionId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (plannedExerciseId.present) {
      map['planned_exercise_id'] = Variable<String>(plannedExerciseId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (supersetGroup.present) {
      map['superset_group'] = Variable<int>(supersetGroup.value);
    }
    if (removed.present) {
      map['removed'] = Variable<bool>(removed.value);
    }
    if (exerciseJson.present) {
      map['exercise_json'] = Variable<String>(exerciseJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionExercisesCompanion(')
          ..write('clientExerciseId: $clientExerciseId, ')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('serverId: $serverId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('plannedExerciseId: $plannedExerciseId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('supersetGroup: $supersetGroup, ')
          ..write('removed: $removed, ')
          ..write('exerciseJson: $exerciseJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSetLogsTable extends LocalSetLogs
    with TableInfo<$LocalSetLogsTable, LocalSetLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSetLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientSetIdMeta =
      const VerificationMeta('clientSetId');
  @override
  late final GeneratedColumn<String> clientSetId = GeneratedColumn<String>(
      'client_set_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientExerciseIdMeta =
      const VerificationMeta('clientExerciseId');
  @override
  late final GeneratedColumn<String> clientExerciseId = GeneratedColumn<String>(
      'client_exercise_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _setIndexMeta =
      const VerificationMeta('setIndex');
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
      'set_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _setTypeMeta =
      const VerificationMeta('setType');
  @override
  late final GeneratedColumn<String> setType = GeneratedColumn<String>(
      'set_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weightKgMeta =
      const VerificationMeta('weightKg');
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
      'weight_kg', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rirMeta = const VerificationMeta('rir');
  @override
  late final GeneratedColumn<int> rir = GeneratedColumn<int>(
      'rir', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<String> loggedAt = GeneratedColumn<String>(
      'logged_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _plannedSetIdMeta =
      const VerificationMeta('plannedSetId');
  @override
  late final GeneratedColumn<String> plannedSetId = GeneratedColumn<String>(
      'planned_set_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isPrMeta = const VerificationMeta('isPr');
  @override
  late final GeneratedColumn<bool> isPr = GeneratedColumn<bool>(
      'is_pr', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_pr" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        clientSetId,
        clientExerciseId,
        serverId,
        setIndex,
        setType,
        weightKg,
        reps,
        rir,
        loggedAt,
        plannedSetId,
        isPr,
        deleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_set_logs';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSetLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_set_id')) {
      context.handle(
          _clientSetIdMeta,
          clientSetId.isAcceptableOrUnknown(
              data['client_set_id']!, _clientSetIdMeta));
    } else if (isInserting) {
      context.missing(_clientSetIdMeta);
    }
    if (data.containsKey('client_exercise_id')) {
      context.handle(
          _clientExerciseIdMeta,
          clientExerciseId.isAcceptableOrUnknown(
              data['client_exercise_id']!, _clientExerciseIdMeta));
    } else if (isInserting) {
      context.missing(_clientExerciseIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('set_index')) {
      context.handle(_setIndexMeta,
          setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta));
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('set_type')) {
      context.handle(_setTypeMeta,
          setType.isAcceptableOrUnknown(data['set_type']!, _setTypeMeta));
    } else if (isInserting) {
      context.missing(_setTypeMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(_weightKgMeta,
          weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta));
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('rir')) {
      context.handle(
          _rirMeta, rir.isAcceptableOrUnknown(data['rir']!, _rirMeta));
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('planned_set_id')) {
      context.handle(
          _plannedSetIdMeta,
          plannedSetId.isAcceptableOrUnknown(
              data['planned_set_id']!, _plannedSetIdMeta));
    }
    if (data.containsKey('is_pr')) {
      context.handle(
          _isPrMeta, isPr.isAcceptableOrUnknown(data['is_pr']!, _isPrMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientSetId};
  @override
  LocalSetLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetLog(
      clientSetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_set_id'])!,
      clientExerciseId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_exercise_id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      setIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}set_index'])!,
      setType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}set_type'])!,
      weightKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_kg']),
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      rir: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rir']),
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logged_at'])!,
      plannedSetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}planned_set_id']),
      isPr: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pr'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
    );
  }

  @override
  $LocalSetLogsTable createAlias(String alias) {
    return $LocalSetLogsTable(attachedDatabase, alias);
  }
}

class LocalSetLog extends DataClass implements Insertable<LocalSetLog> {
  final String clientSetId;
  final String clientExerciseId;
  final String? serverId;
  final int setIndex;
  final String setType;
  final double? weightKg;
  final int reps;
  final int? rir;
  final String loggedAt;
  final String? plannedSetId;
  final bool isPr;
  final bool deleted;
  const LocalSetLog(
      {required this.clientSetId,
      required this.clientExerciseId,
      this.serverId,
      required this.setIndex,
      required this.setType,
      this.weightKg,
      required this.reps,
      this.rir,
      required this.loggedAt,
      this.plannedSetId,
      required this.isPr,
      required this.deleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_set_id'] = Variable<String>(clientSetId);
    map['client_exercise_id'] = Variable<String>(clientExerciseId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['set_index'] = Variable<int>(setIndex);
    map['set_type'] = Variable<String>(setType);
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    map['reps'] = Variable<int>(reps);
    if (!nullToAbsent || rir != null) {
      map['rir'] = Variable<int>(rir);
    }
    map['logged_at'] = Variable<String>(loggedAt);
    if (!nullToAbsent || plannedSetId != null) {
      map['planned_set_id'] = Variable<String>(plannedSetId);
    }
    map['is_pr'] = Variable<bool>(isPr);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  LocalSetLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalSetLogsCompanion(
      clientSetId: Value(clientSetId),
      clientExerciseId: Value(clientExerciseId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      setIndex: Value(setIndex),
      setType: Value(setType),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      reps: Value(reps),
      rir: rir == null && nullToAbsent ? const Value.absent() : Value(rir),
      loggedAt: Value(loggedAt),
      plannedSetId: plannedSetId == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedSetId),
      isPr: Value(isPr),
      deleted: Value(deleted),
    );
  }

  factory LocalSetLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetLog(
      clientSetId: serializer.fromJson<String>(json['clientSetId']),
      clientExerciseId: serializer.fromJson<String>(json['clientExerciseId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      setType: serializer.fromJson<String>(json['setType']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      reps: serializer.fromJson<int>(json['reps']),
      rir: serializer.fromJson<int?>(json['rir']),
      loggedAt: serializer.fromJson<String>(json['loggedAt']),
      plannedSetId: serializer.fromJson<String?>(json['plannedSetId']),
      isPr: serializer.fromJson<bool>(json['isPr']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientSetId': serializer.toJson<String>(clientSetId),
      'clientExerciseId': serializer.toJson<String>(clientExerciseId),
      'serverId': serializer.toJson<String?>(serverId),
      'setIndex': serializer.toJson<int>(setIndex),
      'setType': serializer.toJson<String>(setType),
      'weightKg': serializer.toJson<double?>(weightKg),
      'reps': serializer.toJson<int>(reps),
      'rir': serializer.toJson<int?>(rir),
      'loggedAt': serializer.toJson<String>(loggedAt),
      'plannedSetId': serializer.toJson<String?>(plannedSetId),
      'isPr': serializer.toJson<bool>(isPr),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  LocalSetLog copyWith(
          {String? clientSetId,
          String? clientExerciseId,
          Value<String?> serverId = const Value.absent(),
          int? setIndex,
          String? setType,
          Value<double?> weightKg = const Value.absent(),
          int? reps,
          Value<int?> rir = const Value.absent(),
          String? loggedAt,
          Value<String?> plannedSetId = const Value.absent(),
          bool? isPr,
          bool? deleted}) =>
      LocalSetLog(
        clientSetId: clientSetId ?? this.clientSetId,
        clientExerciseId: clientExerciseId ?? this.clientExerciseId,
        serverId: serverId.present ? serverId.value : this.serverId,
        setIndex: setIndex ?? this.setIndex,
        setType: setType ?? this.setType,
        weightKg: weightKg.present ? weightKg.value : this.weightKg,
        reps: reps ?? this.reps,
        rir: rir.present ? rir.value : this.rir,
        loggedAt: loggedAt ?? this.loggedAt,
        plannedSetId:
            plannedSetId.present ? plannedSetId.value : this.plannedSetId,
        isPr: isPr ?? this.isPr,
        deleted: deleted ?? this.deleted,
      );
  LocalSetLog copyWithCompanion(LocalSetLogsCompanion data) {
    return LocalSetLog(
      clientSetId:
          data.clientSetId.present ? data.clientSetId.value : this.clientSetId,
      clientExerciseId: data.clientExerciseId.present
          ? data.clientExerciseId.value
          : this.clientExerciseId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      setType: data.setType.present ? data.setType.value : this.setType,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      reps: data.reps.present ? data.reps.value : this.reps,
      rir: data.rir.present ? data.rir.value : this.rir,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      plannedSetId: data.plannedSetId.present
          ? data.plannedSetId.value
          : this.plannedSetId,
      isPr: data.isPr.present ? data.isPr.value : this.isPr,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetLog(')
          ..write('clientSetId: $clientSetId, ')
          ..write('clientExerciseId: $clientExerciseId, ')
          ..write('serverId: $serverId, ')
          ..write('setIndex: $setIndex, ')
          ..write('setType: $setType, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('plannedSetId: $plannedSetId, ')
          ..write('isPr: $isPr, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientSetId,
      clientExerciseId,
      serverId,
      setIndex,
      setType,
      weightKg,
      reps,
      rir,
      loggedAt,
      plannedSetId,
      isPr,
      deleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetLog &&
          other.clientSetId == this.clientSetId &&
          other.clientExerciseId == this.clientExerciseId &&
          other.serverId == this.serverId &&
          other.setIndex == this.setIndex &&
          other.setType == this.setType &&
          other.weightKg == this.weightKg &&
          other.reps == this.reps &&
          other.rir == this.rir &&
          other.loggedAt == this.loggedAt &&
          other.plannedSetId == this.plannedSetId &&
          other.isPr == this.isPr &&
          other.deleted == this.deleted);
}

class LocalSetLogsCompanion extends UpdateCompanion<LocalSetLog> {
  final Value<String> clientSetId;
  final Value<String> clientExerciseId;
  final Value<String?> serverId;
  final Value<int> setIndex;
  final Value<String> setType;
  final Value<double?> weightKg;
  final Value<int> reps;
  final Value<int?> rir;
  final Value<String> loggedAt;
  final Value<String?> plannedSetId;
  final Value<bool> isPr;
  final Value<bool> deleted;
  final Value<int> rowid;
  const LocalSetLogsCompanion({
    this.clientSetId = const Value.absent(),
    this.clientExerciseId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.setType = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.reps = const Value.absent(),
    this.rir = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.plannedSetId = const Value.absent(),
    this.isPr = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSetLogsCompanion.insert({
    required String clientSetId,
    required String clientExerciseId,
    this.serverId = const Value.absent(),
    required int setIndex,
    required String setType,
    this.weightKg = const Value.absent(),
    required int reps,
    this.rir = const Value.absent(),
    required String loggedAt,
    this.plannedSetId = const Value.absent(),
    this.isPr = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : clientSetId = Value(clientSetId),
        clientExerciseId = Value(clientExerciseId),
        setIndex = Value(setIndex),
        setType = Value(setType),
        reps = Value(reps),
        loggedAt = Value(loggedAt);
  static Insertable<LocalSetLog> custom({
    Expression<String>? clientSetId,
    Expression<String>? clientExerciseId,
    Expression<String>? serverId,
    Expression<int>? setIndex,
    Expression<String>? setType,
    Expression<double>? weightKg,
    Expression<int>? reps,
    Expression<int>? rir,
    Expression<String>? loggedAt,
    Expression<String>? plannedSetId,
    Expression<bool>? isPr,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientSetId != null) 'client_set_id': clientSetId,
      if (clientExerciseId != null) 'client_exercise_id': clientExerciseId,
      if (serverId != null) 'server_id': serverId,
      if (setIndex != null) 'set_index': setIndex,
      if (setType != null) 'set_type': setType,
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (rir != null) 'rir': rir,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (plannedSetId != null) 'planned_set_id': plannedSetId,
      if (isPr != null) 'is_pr': isPr,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSetLogsCompanion copyWith(
      {Value<String>? clientSetId,
      Value<String>? clientExerciseId,
      Value<String?>? serverId,
      Value<int>? setIndex,
      Value<String>? setType,
      Value<double?>? weightKg,
      Value<int>? reps,
      Value<int?>? rir,
      Value<String>? loggedAt,
      Value<String?>? plannedSetId,
      Value<bool>? isPr,
      Value<bool>? deleted,
      Value<int>? rowid}) {
    return LocalSetLogsCompanion(
      clientSetId: clientSetId ?? this.clientSetId,
      clientExerciseId: clientExerciseId ?? this.clientExerciseId,
      serverId: serverId ?? this.serverId,
      setIndex: setIndex ?? this.setIndex,
      setType: setType ?? this.setType,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      rir: rir ?? this.rir,
      loggedAt: loggedAt ?? this.loggedAt,
      plannedSetId: plannedSetId ?? this.plannedSetId,
      isPr: isPr ?? this.isPr,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientSetId.present) {
      map['client_set_id'] = Variable<String>(clientSetId.value);
    }
    if (clientExerciseId.present) {
      map['client_exercise_id'] = Variable<String>(clientExerciseId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (setType.present) {
      map['set_type'] = Variable<String>(setType.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (rir.present) {
      map['rir'] = Variable<int>(rir.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<String>(loggedAt.value);
    }
    if (plannedSetId.present) {
      map['planned_set_id'] = Variable<String>(plannedSetId.value);
    }
    if (isPr.present) {
      map['is_pr'] = Variable<bool>(isPr.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetLogsCompanion(')
          ..write('clientSetId: $clientSetId, ')
          ..write('clientExerciseId: $clientExerciseId, ')
          ..write('serverId: $serverId, ')
          ..write('setIndex: $setIndex, ')
          ..write('setType: $setType, ')
          ..write('weightKg: $weightKg, ')
          ..write('reps: $reps, ')
          ..write('rir: $rir, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('plannedSetId: $plannedSetId, ')
          ..write('isPr: $isPr, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueTable extends SyncQueue
    with TableInfo<$SyncQueueTable, SyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientSessionIdMeta =
      const VerificationMeta('clientSessionId');
  @override
  late final GeneratedColumn<String> clientSessionId = GeneratedColumn<String>(
      'client_session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientKeyMeta =
      const VerificationMeta('clientKey');
  @override
  late final GeneratedColumn<String> clientKey = GeneratedColumn<String>(
      'client_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<String> nextAttemptAt = GeneratedColumn<String>(
      'next_attempt_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parkedMeta = const VerificationMeta('parked');
  @override
  late final GeneratedColumn<bool> parked = GeneratedColumn<bool>(
      'parked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("parked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        kind,
        clientSessionId,
        clientKey,
        payloadJson,
        attempts,
        nextAttemptAt,
        lastError,
        parked,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('client_session_id')) {
      context.handle(
          _clientSessionIdMeta,
          clientSessionId.isAcceptableOrUnknown(
              data['client_session_id']!, _clientSessionIdMeta));
    } else if (isInserting) {
      context.missing(_clientSessionIdMeta);
    }
    if (data.containsKey('client_key')) {
      context.handle(_clientKeyMeta,
          clientKey.isAcceptableOrUnknown(data['client_key']!, _clientKeyMeta));
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('parked')) {
      context.handle(_parkedMeta,
          parked.isAcceptableOrUnknown(data['parked']!, _parkedMeta));
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
  SyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      clientSessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_session_id'])!,
      clientKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_key']),
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextAttemptAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_attempt_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      parked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}parked'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncQueueTable createAlias(String alias) {
    return $SyncQueueTable(attachedDatabase, alias);
  }
}

class SyncQueueData extends DataClass implements Insertable<SyncQueueData> {
  final int id;

  /// `start` | `logSets` | `patchSet` | `deleteSet` | `addExercise` |
  /// `patchExercise` | `complete` | `abandon`.
  final String kind;
  final String clientSessionId;

  /// The row this mutation is about (a client set id, a client exercise id).
  final String? clientKey;
  final String payloadJson;
  final int attempts;
  final String? nextAttemptAt;
  final String? lastError;

  /// Parked: gave up after the retry budget; shown to the user with Retry.
  final bool parked;
  final String createdAt;
  const SyncQueueData(
      {required this.id,
      required this.kind,
      required this.clientSessionId,
      this.clientKey,
      required this.payloadJson,
      required this.attempts,
      this.nextAttemptAt,
      this.lastError,
      required this.parked,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['client_session_id'] = Variable<String>(clientSessionId);
    if (!nullToAbsent || clientKey != null) {
      map['client_key'] = Variable<String>(clientKey);
    }
    map['payload_json'] = Variable<String>(payloadJson);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['parked'] = Variable<bool>(parked);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  SyncQueueCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueCompanion(
      id: Value(id),
      kind: Value(kind),
      clientSessionId: Value(clientSessionId),
      clientKey: clientKey == null && nullToAbsent
          ? const Value.absent()
          : Value(clientKey),
      payloadJson: Value(payloadJson),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      parked: Value(parked),
      createdAt: Value(createdAt),
    );
  }

  factory SyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      clientSessionId: serializer.fromJson<String>(json['clientSessionId']),
      clientKey: serializer.fromJson<String?>(json['clientKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<String?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      parked: serializer.fromJson<bool>(json['parked']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'clientSessionId': serializer.toJson<String>(clientSessionId),
      'clientKey': serializer.toJson<String?>(clientKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<String?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'parked': serializer.toJson<bool>(parked),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  SyncQueueData copyWith(
          {int? id,
          String? kind,
          String? clientSessionId,
          Value<String?> clientKey = const Value.absent(),
          String? payloadJson,
          int? attempts,
          Value<String?> nextAttemptAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          bool? parked,
          String? createdAt}) =>
      SyncQueueData(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        clientSessionId: clientSessionId ?? this.clientSessionId,
        clientKey: clientKey.present ? clientKey.value : this.clientKey,
        payloadJson: payloadJson ?? this.payloadJson,
        attempts: attempts ?? this.attempts,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        parked: parked ?? this.parked,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncQueueData copyWithCompanion(SyncQueueCompanion data) {
    return SyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      clientSessionId: data.clientSessionId.present
          ? data.clientSessionId.value
          : this.clientSessionId,
      clientKey: data.clientKey.present ? data.clientKey.value : this.clientKey,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      parked: data.parked.present ? data.parked.value : this.parked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('clientKey: $clientKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, clientSessionId, clientKey,
      payloadJson, attempts, nextAttemptAt, lastError, parked, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.clientSessionId == this.clientSessionId &&
          other.clientKey == this.clientKey &&
          other.payloadJson == this.payloadJson &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.parked == this.parked &&
          other.createdAt == this.createdAt);
}

class SyncQueueCompanion extends UpdateCompanion<SyncQueueData> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> clientSessionId;
  final Value<String?> clientKey;
  final Value<String> payloadJson;
  final Value<int> attempts;
  final Value<String?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<bool> parked;
  final Value<String> createdAt;
  const SyncQueueCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.clientSessionId = const Value.absent(),
    this.clientKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String clientSessionId,
    this.clientKey = const Value.absent(),
    required String payloadJson,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    required String createdAt,
  })  : kind = Value(kind),
        clientSessionId = Value(clientSessionId),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<SyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? clientSessionId,
    Expression<String>? clientKey,
    Expression<String>? payloadJson,
    Expression<int>? attempts,
    Expression<String>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<bool>? parked,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (clientSessionId != null) 'client_session_id': clientSessionId,
      if (clientKey != null) 'client_key': clientKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (parked != null) 'parked': parked,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? kind,
      Value<String>? clientSessionId,
      Value<String?>? clientKey,
      Value<String>? payloadJson,
      Value<int>? attempts,
      Value<String?>? nextAttemptAt,
      Value<String?>? lastError,
      Value<bool>? parked,
      Value<String>? createdAt}) {
    return SyncQueueCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      clientSessionId: clientSessionId ?? this.clientSessionId,
      clientKey: clientKey ?? this.clientKey,
      payloadJson: payloadJson ?? this.payloadJson,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      parked: parked ?? this.parked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (clientSessionId.present) {
      map['client_session_id'] = Variable<String>(clientSessionId.value);
    }
    if (clientKey.present) {
      map['client_key'] = Variable<String>(clientKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (parked.present) {
      map['parked'] = Variable<bool>(parked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientSessionId: $clientSessionId, ')
          ..write('clientKey: $clientKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedJsonTable extends CachedJson
    with TableInfo<$CachedJsonTable, CachedJsonData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedJsonTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _storedAtMeta =
      const VerificationMeta('storedAt');
  @override
  late final GeneratedColumn<String> storedAt = GeneratedColumn<String>(
      'stored_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, json, storedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_json';
  @override
  VerificationContext validateIntegrity(Insertable<CachedJsonData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('stored_at')) {
      context.handle(_storedAtMeta,
          storedAt.isAcceptableOrUnknown(data['stored_at']!, _storedAtMeta));
    } else if (isInserting) {
      context.missing(_storedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedJsonData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedJsonData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      storedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stored_at'])!,
    );
  }

  @override
  $CachedJsonTable createAlias(String alias) {
    return $CachedJsonTable(attachedDatabase, alias);
  }
}

class CachedJsonData extends DataClass implements Insertable<CachedJsonData> {
  final String key;
  final String json;
  final String storedAt;
  const CachedJsonData(
      {required this.key, required this.json, required this.storedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    map['stored_at'] = Variable<String>(storedAt);
    return map;
  }

  CachedJsonCompanion toCompanion(bool nullToAbsent) {
    return CachedJsonCompanion(
      key: Value(key),
      json: Value(json),
      storedAt: Value(storedAt),
    );
  }

  factory CachedJsonData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedJsonData(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
      storedAt: serializer.fromJson<String>(json['storedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
      'storedAt': serializer.toJson<String>(storedAt),
    };
  }

  CachedJsonData copyWith({String? key, String? json, String? storedAt}) =>
      CachedJsonData(
        key: key ?? this.key,
        json: json ?? this.json,
        storedAt: storedAt ?? this.storedAt,
      );
  CachedJsonData copyWithCompanion(CachedJsonCompanion data) {
    return CachedJsonData(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
      storedAt: data.storedAt.present ? data.storedAt.value : this.storedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedJsonData(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('storedAt: $storedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json, storedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedJsonData &&
          other.key == this.key &&
          other.json == this.json &&
          other.storedAt == this.storedAt);
}

class CachedJsonCompanion extends UpdateCompanion<CachedJsonData> {
  final Value<String> key;
  final Value<String> json;
  final Value<String> storedAt;
  final Value<int> rowid;
  const CachedJsonCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.storedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedJsonCompanion.insert({
    required String key,
    required String json,
    required String storedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        json = Value(json),
        storedAt = Value(storedAt);
  static Insertable<CachedJsonData> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<String>? storedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (storedAt != null) 'stored_at': storedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedJsonCompanion copyWith(
      {Value<String>? key,
      Value<String>? json,
      Value<String>? storedAt,
      Value<int>? rowid}) {
    return CachedJsonCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      storedAt: storedAt ?? this.storedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (storedAt.present) {
      map['stored_at'] = Variable<String>(storedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedJsonCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('storedAt: $storedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalFoodLogsTable extends LocalFoodLogs
    with TableInfo<$LocalFoodLogsTable, LocalFoodLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalFoodLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientLogIdMeta =
      const VerificationMeta('clientLogId');
  @override
  late final GeneratedColumn<String> clientLogId = GeneratedColumn<String>(
      'client_log_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localDateMeta =
      const VerificationMeta('localDate');
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
      'local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mealSlotMeta =
      const VerificationMeta('mealSlot');
  @override
  late final GeneratedColumn<String> mealSlot = GeneratedColumn<String>(
      'meal_slot', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _loggedAtMeta =
      const VerificationMeta('loggedAt');
  @override
  late final GeneratedColumn<String> loggedAt = GeneratedColumn<String>(
      'logged_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _requestJsonMeta =
      const VerificationMeta('requestJson');
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
      'request_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _previewJsonMeta =
      const VerificationMeta('previewJson');
  @override
  late final GeneratedColumn<String> previewJson = GeneratedColumn<String>(
      'preview_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientLogId,
        localDate,
        mealSlot,
        loggedAt,
        requestJson,
        previewJson,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_food_logs';
  @override
  VerificationContext validateIntegrity(Insertable<LocalFoodLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_log_id')) {
      context.handle(
          _clientLogIdMeta,
          clientLogId.isAcceptableOrUnknown(
              data['client_log_id']!, _clientLogIdMeta));
    } else if (isInserting) {
      context.missing(_clientLogIdMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(_localDateMeta,
          localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta));
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('meal_slot')) {
      context.handle(_mealSlotMeta,
          mealSlot.isAcceptableOrUnknown(data['meal_slot']!, _mealSlotMeta));
    } else if (isInserting) {
      context.missing(_mealSlotMeta);
    }
    if (data.containsKey('logged_at')) {
      context.handle(_loggedAtMeta,
          loggedAt.isAcceptableOrUnknown(data['logged_at']!, _loggedAtMeta));
    } else if (isInserting) {
      context.missing(_loggedAtMeta);
    }
    if (data.containsKey('request_json')) {
      context.handle(
          _requestJsonMeta,
          requestJson.isAcceptableOrUnknown(
              data['request_json']!, _requestJsonMeta));
    } else if (isInserting) {
      context.missing(_requestJsonMeta);
    }
    if (data.containsKey('preview_json')) {
      context.handle(
          _previewJsonMeta,
          previewJson.isAcceptableOrUnknown(
              data['preview_json']!, _previewJsonMeta));
    } else if (isInserting) {
      context.missing(_previewJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {clientLogId};
  @override
  LocalFoodLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalFoodLog(
      clientLogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_log_id'])!,
      localDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_date'])!,
      mealSlot: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meal_slot'])!,
      loggedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}logged_at'])!,
      requestJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}request_json'])!,
      previewJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preview_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalFoodLogsTable createAlias(String alias) {
    return $LocalFoodLogsTable(attachedDatabase, alias);
  }
}

class LocalFoodLog extends DataClass implements Insertable<LocalFoodLog> {
  final String clientLogId;

  /// The day it is shown on until synced (the user's zone); the server decides.
  final String localDate;
  final String mealSlot;
  final String loggedAt;

  /// The `POST /nutrition/logs` body, sent as is.
  final String requestJson;
  final String previewJson;
  final String createdAt;
  const LocalFoodLog(
      {required this.clientLogId,
      required this.localDate,
      required this.mealSlot,
      required this.loggedAt,
      required this.requestJson,
      required this.previewJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_log_id'] = Variable<String>(clientLogId);
    map['local_date'] = Variable<String>(localDate);
    map['meal_slot'] = Variable<String>(mealSlot);
    map['logged_at'] = Variable<String>(loggedAt);
    map['request_json'] = Variable<String>(requestJson);
    map['preview_json'] = Variable<String>(previewJson);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalFoodLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalFoodLogsCompanion(
      clientLogId: Value(clientLogId),
      localDate: Value(localDate),
      mealSlot: Value(mealSlot),
      loggedAt: Value(loggedAt),
      requestJson: Value(requestJson),
      previewJson: Value(previewJson),
      createdAt: Value(createdAt),
    );
  }

  factory LocalFoodLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalFoodLog(
      clientLogId: serializer.fromJson<String>(json['clientLogId']),
      localDate: serializer.fromJson<String>(json['localDate']),
      mealSlot: serializer.fromJson<String>(json['mealSlot']),
      loggedAt: serializer.fromJson<String>(json['loggedAt']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      previewJson: serializer.fromJson<String>(json['previewJson']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientLogId': serializer.toJson<String>(clientLogId),
      'localDate': serializer.toJson<String>(localDate),
      'mealSlot': serializer.toJson<String>(mealSlot),
      'loggedAt': serializer.toJson<String>(loggedAt),
      'requestJson': serializer.toJson<String>(requestJson),
      'previewJson': serializer.toJson<String>(previewJson),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalFoodLog copyWith(
          {String? clientLogId,
          String? localDate,
          String? mealSlot,
          String? loggedAt,
          String? requestJson,
          String? previewJson,
          String? createdAt}) =>
      LocalFoodLog(
        clientLogId: clientLogId ?? this.clientLogId,
        localDate: localDate ?? this.localDate,
        mealSlot: mealSlot ?? this.mealSlot,
        loggedAt: loggedAt ?? this.loggedAt,
        requestJson: requestJson ?? this.requestJson,
        previewJson: previewJson ?? this.previewJson,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalFoodLog copyWithCompanion(LocalFoodLogsCompanion data) {
    return LocalFoodLog(
      clientLogId:
          data.clientLogId.present ? data.clientLogId.value : this.clientLogId,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      mealSlot: data.mealSlot.present ? data.mealSlot.value : this.mealSlot,
      loggedAt: data.loggedAt.present ? data.loggedAt.value : this.loggedAt,
      requestJson:
          data.requestJson.present ? data.requestJson.value : this.requestJson,
      previewJson:
          data.previewJson.present ? data.previewJson.value : this.previewJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalFoodLog(')
          ..write('clientLogId: $clientLogId, ')
          ..write('localDate: $localDate, ')
          ..write('mealSlot: $mealSlot, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('requestJson: $requestJson, ')
          ..write('previewJson: $previewJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientLogId, localDate, mealSlot, loggedAt,
      requestJson, previewJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalFoodLog &&
          other.clientLogId == this.clientLogId &&
          other.localDate == this.localDate &&
          other.mealSlot == this.mealSlot &&
          other.loggedAt == this.loggedAt &&
          other.requestJson == this.requestJson &&
          other.previewJson == this.previewJson &&
          other.createdAt == this.createdAt);
}

class LocalFoodLogsCompanion extends UpdateCompanion<LocalFoodLog> {
  final Value<String> clientLogId;
  final Value<String> localDate;
  final Value<String> mealSlot;
  final Value<String> loggedAt;
  final Value<String> requestJson;
  final Value<String> previewJson;
  final Value<String> createdAt;
  final Value<int> rowid;
  const LocalFoodLogsCompanion({
    this.clientLogId = const Value.absent(),
    this.localDate = const Value.absent(),
    this.mealSlot = const Value.absent(),
    this.loggedAt = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.previewJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalFoodLogsCompanion.insert({
    required String clientLogId,
    required String localDate,
    required String mealSlot,
    required String loggedAt,
    required String requestJson,
    required String previewJson,
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : clientLogId = Value(clientLogId),
        localDate = Value(localDate),
        mealSlot = Value(mealSlot),
        loggedAt = Value(loggedAt),
        requestJson = Value(requestJson),
        previewJson = Value(previewJson),
        createdAt = Value(createdAt);
  static Insertable<LocalFoodLog> custom({
    Expression<String>? clientLogId,
    Expression<String>? localDate,
    Expression<String>? mealSlot,
    Expression<String>? loggedAt,
    Expression<String>? requestJson,
    Expression<String>? previewJson,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientLogId != null) 'client_log_id': clientLogId,
      if (localDate != null) 'local_date': localDate,
      if (mealSlot != null) 'meal_slot': mealSlot,
      if (loggedAt != null) 'logged_at': loggedAt,
      if (requestJson != null) 'request_json': requestJson,
      if (previewJson != null) 'preview_json': previewJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalFoodLogsCompanion copyWith(
      {Value<String>? clientLogId,
      Value<String>? localDate,
      Value<String>? mealSlot,
      Value<String>? loggedAt,
      Value<String>? requestJson,
      Value<String>? previewJson,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return LocalFoodLogsCompanion(
      clientLogId: clientLogId ?? this.clientLogId,
      localDate: localDate ?? this.localDate,
      mealSlot: mealSlot ?? this.mealSlot,
      loggedAt: loggedAt ?? this.loggedAt,
      requestJson: requestJson ?? this.requestJson,
      previewJson: previewJson ?? this.previewJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientLogId.present) {
      map['client_log_id'] = Variable<String>(clientLogId.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (mealSlot.present) {
      map['meal_slot'] = Variable<String>(mealSlot.value);
    }
    if (loggedAt.present) {
      map['logged_at'] = Variable<String>(loggedAt.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (previewJson.present) {
      map['preview_json'] = Variable<String>(previewJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalFoodLogsCompanion(')
          ..write('clientLogId: $clientLogId, ')
          ..write('localDate: $localDate, ')
          ..write('mealSlot: $mealSlot, ')
          ..write('loggedAt: $loggedAt, ')
          ..write('requestJson: $requestJson, ')
          ..write('previewJson: $previewJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NutritionSyncQueueTable extends NutritionSyncQueue
    with TableInfo<$NutritionSyncQueueTable, NutritionSyncQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NutritionSyncQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientLogIdMeta =
      const VerificationMeta('clientLogId');
  @override
  late final GeneratedColumn<String> clientLogId = GeneratedColumn<String>(
      'client_log_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadJsonMeta =
      const VerificationMeta('payloadJson');
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
      'payload_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<String> nextAttemptAt = GeneratedColumn<String>(
      'next_attempt_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parkedMeta = const VerificationMeta('parked');
  @override
  late final GeneratedColumn<bool> parked = GeneratedColumn<bool>(
      'parked', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("parked" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        kind,
        clientLogId,
        payloadJson,
        attempts,
        nextAttemptAt,
        lastError,
        parked,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'nutrition_sync_queue';
  @override
  VerificationContext validateIntegrity(
      Insertable<NutritionSyncQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('client_log_id')) {
      context.handle(
          _clientLogIdMeta,
          clientLogId.isAcceptableOrUnknown(
              data['client_log_id']!, _clientLogIdMeta));
    } else if (isInserting) {
      context.missing(_clientLogIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
          _payloadJsonMeta,
          payloadJson.isAcceptableOrUnknown(
              data['payload_json']!, _payloadJsonMeta));
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('parked')) {
      context.handle(_parkedMeta,
          parked.isAcceptableOrUnknown(data['parked']!, _parkedMeta));
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
  NutritionSyncQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NutritionSyncQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      clientLogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_log_id'])!,
      payloadJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload_json'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextAttemptAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_attempt_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      parked: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}parked'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $NutritionSyncQueueTable createAlias(String alias) {
    return $NutritionSyncQueueTable(attachedDatabase, alias);
  }
}

class NutritionSyncQueueData extends DataClass
    implements Insertable<NutritionSyncQueueData> {
  final int id;

  /// `create` | `delete`.
  final String kind;
  final String clientLogId;
  final String payloadJson;
  final int attempts;
  final String? nextAttemptAt;
  final String? lastError;
  final bool parked;
  final String createdAt;
  const NutritionSyncQueueData(
      {required this.id,
      required this.kind,
      required this.clientLogId,
      required this.payloadJson,
      required this.attempts,
      this.nextAttemptAt,
      this.lastError,
      required this.parked,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['client_log_id'] = Variable<String>(clientLogId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['parked'] = Variable<bool>(parked);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  NutritionSyncQueueCompanion toCompanion(bool nullToAbsent) {
    return NutritionSyncQueueCompanion(
      id: Value(id),
      kind: Value(kind),
      clientLogId: Value(clientLogId),
      payloadJson: Value(payloadJson),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      parked: Value(parked),
      createdAt: Value(createdAt),
    );
  }

  factory NutritionSyncQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NutritionSyncQueueData(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      clientLogId: serializer.fromJson<String>(json['clientLogId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<String?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      parked: serializer.fromJson<bool>(json['parked']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'clientLogId': serializer.toJson<String>(clientLogId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<String?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'parked': serializer.toJson<bool>(parked),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  NutritionSyncQueueData copyWith(
          {int? id,
          String? kind,
          String? clientLogId,
          String? payloadJson,
          int? attempts,
          Value<String?> nextAttemptAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          bool? parked,
          String? createdAt}) =>
      NutritionSyncQueueData(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        clientLogId: clientLogId ?? this.clientLogId,
        payloadJson: payloadJson ?? this.payloadJson,
        attempts: attempts ?? this.attempts,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        parked: parked ?? this.parked,
        createdAt: createdAt ?? this.createdAt,
      );
  NutritionSyncQueueData copyWithCompanion(NutritionSyncQueueCompanion data) {
    return NutritionSyncQueueData(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      clientLogId:
          data.clientLogId.present ? data.clientLogId.value : this.clientLogId,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      parked: data.parked.present ? data.parked.value : this.parked,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NutritionSyncQueueData(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientLogId: $clientLogId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, clientLogId, payloadJson, attempts,
      nextAttemptAt, lastError, parked, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NutritionSyncQueueData &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.clientLogId == this.clientLogId &&
          other.payloadJson == this.payloadJson &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.parked == this.parked &&
          other.createdAt == this.createdAt);
}

class NutritionSyncQueueCompanion
    extends UpdateCompanion<NutritionSyncQueueData> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> clientLogId;
  final Value<String> payloadJson;
  final Value<int> attempts;
  final Value<String?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<bool> parked;
  final Value<String> createdAt;
  const NutritionSyncQueueCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.clientLogId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  NutritionSyncQueueCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String clientLogId,
    required String payloadJson,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.parked = const Value.absent(),
    required String createdAt,
  })  : kind = Value(kind),
        clientLogId = Value(clientLogId),
        payloadJson = Value(payloadJson),
        createdAt = Value(createdAt);
  static Insertable<NutritionSyncQueueData> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? clientLogId,
    Expression<String>? payloadJson,
    Expression<int>? attempts,
    Expression<String>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<bool>? parked,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (clientLogId != null) 'client_log_id': clientLogId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (parked != null) 'parked': parked,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  NutritionSyncQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? kind,
      Value<String>? clientLogId,
      Value<String>? payloadJson,
      Value<int>? attempts,
      Value<String?>? nextAttemptAt,
      Value<String?>? lastError,
      Value<bool>? parked,
      Value<String>? createdAt}) {
    return NutritionSyncQueueCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      clientLogId: clientLogId ?? this.clientLogId,
      payloadJson: payloadJson ?? this.payloadJson,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      parked: parked ?? this.parked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (clientLogId.present) {
      map['client_log_id'] = Variable<String>(clientLogId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (parked.present) {
      map['parked'] = Variable<bool>(parked.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NutritionSyncQueueCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('clientLogId: $clientLogId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('parked: $parked, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TodayEventQueueTable extends TodayEventQueue
    with TableInfo<$TodayEventQueueTable, TodayEventQueueData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodayEventQueueTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _clientEventIdMeta =
      const VerificationMeta('clientEventId');
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
      'client_event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recommendationIdMeta =
      const VerificationMeta('recommendationId');
  @override
  late final GeneratedColumn<String> recommendationId = GeneratedColumn<String>(
      'recommendation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
      'event', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _nextAttemptAtMeta =
      const VerificationMeta('nextAttemptAt');
  @override
  late final GeneratedColumn<String> nextAttemptAt = GeneratedColumn<String>(
      'next_attempt_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        clientEventId,
        recommendationId,
        event,
        occurredAt,
        attempts,
        nextAttemptAt,
        lastError,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'today_event_queue';
  @override
  VerificationContext validateIntegrity(
      Insertable<TodayEventQueueData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
          _clientEventIdMeta,
          clientEventId.isAcceptableOrUnknown(
              data['client_event_id']!, _clientEventIdMeta));
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('recommendation_id')) {
      context.handle(
          _recommendationIdMeta,
          recommendationId.isAcceptableOrUnknown(
              data['recommendation_id']!, _recommendationIdMeta));
    } else if (isInserting) {
      context.missing(_recommendationIdMeta);
    }
    if (data.containsKey('event')) {
      context.handle(
          _eventMeta, event.isAcceptableOrUnknown(data['event']!, _eventMeta));
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
          _nextAttemptAtMeta,
          nextAttemptAt.isAcceptableOrUnknown(
              data['next_attempt_at']!, _nextAttemptAtMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
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
  TodayEventQueueData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodayEventQueueData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      clientEventId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_event_id'])!,
      recommendationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}recommendation_id'])!,
      event: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurred_at'])!,
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      nextAttemptAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_attempt_at']),
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TodayEventQueueTable createAlias(String alias) {
    return $TodayEventQueueTable(attachedDatabase, alias);
  }
}

class TodayEventQueueData extends DataClass
    implements Insertable<TodayEventQueueData> {
  final int id;

  /// Minted once when the event happened; every retry reuses it.
  final String clientEventId;
  final String recommendationId;

  /// `shown` | `opened` | `accepted` | `dismissed` | `completed`.
  final String event;

  /// When it happened on this phone (UTC ISO) — sent as is, never "now".
  final String occurredAt;
  final int attempts;
  final String? nextAttemptAt;
  final String? lastError;
  final String createdAt;
  const TodayEventQueueData(
      {required this.id,
      required this.clientEventId,
      required this.recommendationId,
      required this.event,
      required this.occurredAt,
      required this.attempts,
      this.nextAttemptAt,
      this.lastError,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['recommendation_id'] = Variable<String>(recommendationId);
    map['event'] = Variable<String>(event);
    map['occurred_at'] = Variable<String>(occurredAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  TodayEventQueueCompanion toCompanion(bool nullToAbsent) {
    return TodayEventQueueCompanion(
      id: Value(id),
      clientEventId: Value(clientEventId),
      recommendationId: Value(recommendationId),
      event: Value(event),
      occurredAt: Value(occurredAt),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory TodayEventQueueData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodayEventQueueData(
      id: serializer.fromJson<int>(json['id']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      recommendationId: serializer.fromJson<String>(json['recommendationId']),
      event: serializer.fromJson<String>(json['event']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<String?>(json['nextAttemptAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'recommendationId': serializer.toJson<String>(recommendationId),
      'event': serializer.toJson<String>(event),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<String?>(nextAttemptAt),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  TodayEventQueueData copyWith(
          {int? id,
          String? clientEventId,
          String? recommendationId,
          String? event,
          String? occurredAt,
          int? attempts,
          Value<String?> nextAttemptAt = const Value.absent(),
          Value<String?> lastError = const Value.absent(),
          String? createdAt}) =>
      TodayEventQueueData(
        id: id ?? this.id,
        clientEventId: clientEventId ?? this.clientEventId,
        recommendationId: recommendationId ?? this.recommendationId,
        event: event ?? this.event,
        occurredAt: occurredAt ?? this.occurredAt,
        attempts: attempts ?? this.attempts,
        nextAttemptAt:
            nextAttemptAt.present ? nextAttemptAt.value : this.nextAttemptAt,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
      );
  TodayEventQueueData copyWithCompanion(TodayEventQueueCompanion data) {
    return TodayEventQueueData(
      id: data.id.present ? data.id.value : this.id,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      recommendationId: data.recommendationId.present
          ? data.recommendationId.value
          : this.recommendationId,
      event: data.event.present ? data.event.value : this.event,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodayEventQueueData(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('recommendationId: $recommendationId, ')
          ..write('event: $event, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, clientEventId, recommendationId, event,
      occurredAt, attempts, nextAttemptAt, lastError, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodayEventQueueData &&
          other.id == this.id &&
          other.clientEventId == this.clientEventId &&
          other.recommendationId == this.recommendationId &&
          other.event == this.event &&
          other.occurredAt == this.occurredAt &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class TodayEventQueueCompanion extends UpdateCompanion<TodayEventQueueData> {
  final Value<int> id;
  final Value<String> clientEventId;
  final Value<String> recommendationId;
  final Value<String> event;
  final Value<String> occurredAt;
  final Value<int> attempts;
  final Value<String?> nextAttemptAt;
  final Value<String?> lastError;
  final Value<String> createdAt;
  const TodayEventQueueCompanion({
    this.id = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.recommendationId = const Value.absent(),
    this.event = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TodayEventQueueCompanion.insert({
    this.id = const Value.absent(),
    required String clientEventId,
    required String recommendationId,
    required String event,
    required String occurredAt,
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.lastError = const Value.absent(),
    required String createdAt,
  })  : clientEventId = Value(clientEventId),
        recommendationId = Value(recommendationId),
        event = Value(event),
        occurredAt = Value(occurredAt),
        createdAt = Value(createdAt);
  static Insertable<TodayEventQueueData> custom({
    Expression<int>? id,
    Expression<String>? clientEventId,
    Expression<String>? recommendationId,
    Expression<String>? event,
    Expression<String>? occurredAt,
    Expression<int>? attempts,
    Expression<String>? nextAttemptAt,
    Expression<String>? lastError,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (recommendationId != null) 'recommendation_id': recommendationId,
      if (event != null) 'event': event,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TodayEventQueueCompanion copyWith(
      {Value<int>? id,
      Value<String>? clientEventId,
      Value<String>? recommendationId,
      Value<String>? event,
      Value<String>? occurredAt,
      Value<int>? attempts,
      Value<String?>? nextAttemptAt,
      Value<String?>? lastError,
      Value<String>? createdAt}) {
    return TodayEventQueueCompanion(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      recommendationId: recommendationId ?? this.recommendationId,
      event: event ?? this.event,
      occurredAt: occurredAt ?? this.occurredAt,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (recommendationId.present) {
      map['recommendation_id'] = Variable<String>(recommendationId.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<String>(nextAttemptAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodayEventQueueCompanion(')
          ..write('id: $id, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('recommendationId: $recommendationId, ')
          ..write('event: $event, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TodayEventLedgerTable extends TodayEventLedger
    with TableInfo<$TodayEventLedgerTable, TodayEventLedgerData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodayEventLedgerTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recommendationIdMeta =
      const VerificationMeta('recommendationId');
  @override
  late final GeneratedColumn<String> recommendationId = GeneratedColumn<String>(
      'recommendation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eventMeta = const VerificationMeta('event');
  @override
  late final GeneratedColumn<String> event = GeneratedColumn<String>(
      'event', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _clientEventIdMeta =
      const VerificationMeta('clientEventId');
  @override
  late final GeneratedColumn<String> clientEventId = GeneratedColumn<String>(
      'client_event_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectKeyMeta =
      const VerificationMeta('subjectKey');
  @override
  late final GeneratedColumn<String> subjectKey = GeneratedColumn<String>(
      'subject_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localDateMeta =
      const VerificationMeta('localDate');
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
      'local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<String> occurredAt = GeneratedColumn<String>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        recommendationId,
        event,
        clientEventId,
        kind,
        subjectKey,
        localDate,
        occurredAt,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'today_event_ledger';
  @override
  VerificationContext validateIntegrity(
      Insertable<TodayEventLedgerData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recommendation_id')) {
      context.handle(
          _recommendationIdMeta,
          recommendationId.isAcceptableOrUnknown(
              data['recommendation_id']!, _recommendationIdMeta));
    } else if (isInserting) {
      context.missing(_recommendationIdMeta);
    }
    if (data.containsKey('event')) {
      context.handle(
          _eventMeta, event.isAcceptableOrUnknown(data['event']!, _eventMeta));
    } else if (isInserting) {
      context.missing(_eventMeta);
    }
    if (data.containsKey('client_event_id')) {
      context.handle(
          _clientEventIdMeta,
          clientEventId.isAcceptableOrUnknown(
              data['client_event_id']!, _clientEventIdMeta));
    } else if (isInserting) {
      context.missing(_clientEventIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('subject_key')) {
      context.handle(
          _subjectKeyMeta,
          subjectKey.isAcceptableOrUnknown(
              data['subject_key']!, _subjectKeyMeta));
    } else if (isInserting) {
      context.missing(_subjectKeyMeta);
    }
    if (data.containsKey('local_date')) {
      context.handle(_localDateMeta,
          localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta));
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recommendationId, event};
  @override
  TodayEventLedgerData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TodayEventLedgerData(
      recommendationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}recommendation_id'])!,
      event: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}event'])!,
      clientEventId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_event_id'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      subjectKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_key'])!,
      localDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_date'])!,
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occurred_at'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $TodayEventLedgerTable createAlias(String alias) {
    return $TodayEventLedgerTable(attachedDatabase, alias);
  }
}

class TodayEventLedgerData extends DataClass
    implements Insertable<TodayEventLedgerData> {
  final String recommendationId;
  final String event;
  final String clientEventId;
  final String kind;
  final String subjectKey;

  /// The action's local date (the server's `generated_for`).
  final String localDate;
  final String occurredAt;

  /// `queued` | `sent` | `rejected` | `failed`.
  final String status;
  const TodayEventLedgerData(
      {required this.recommendationId,
      required this.event,
      required this.clientEventId,
      required this.kind,
      required this.subjectKey,
      required this.localDate,
      required this.occurredAt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recommendation_id'] = Variable<String>(recommendationId);
    map['event'] = Variable<String>(event);
    map['client_event_id'] = Variable<String>(clientEventId);
    map['kind'] = Variable<String>(kind);
    map['subject_key'] = Variable<String>(subjectKey);
    map['local_date'] = Variable<String>(localDate);
    map['occurred_at'] = Variable<String>(occurredAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  TodayEventLedgerCompanion toCompanion(bool nullToAbsent) {
    return TodayEventLedgerCompanion(
      recommendationId: Value(recommendationId),
      event: Value(event),
      clientEventId: Value(clientEventId),
      kind: Value(kind),
      subjectKey: Value(subjectKey),
      localDate: Value(localDate),
      occurredAt: Value(occurredAt),
      status: Value(status),
    );
  }

  factory TodayEventLedgerData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TodayEventLedgerData(
      recommendationId: serializer.fromJson<String>(json['recommendationId']),
      event: serializer.fromJson<String>(json['event']),
      clientEventId: serializer.fromJson<String>(json['clientEventId']),
      kind: serializer.fromJson<String>(json['kind']),
      subjectKey: serializer.fromJson<String>(json['subjectKey']),
      localDate: serializer.fromJson<String>(json['localDate']),
      occurredAt: serializer.fromJson<String>(json['occurredAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recommendationId': serializer.toJson<String>(recommendationId),
      'event': serializer.toJson<String>(event),
      'clientEventId': serializer.toJson<String>(clientEventId),
      'kind': serializer.toJson<String>(kind),
      'subjectKey': serializer.toJson<String>(subjectKey),
      'localDate': serializer.toJson<String>(localDate),
      'occurredAt': serializer.toJson<String>(occurredAt),
      'status': serializer.toJson<String>(status),
    };
  }

  TodayEventLedgerData copyWith(
          {String? recommendationId,
          String? event,
          String? clientEventId,
          String? kind,
          String? subjectKey,
          String? localDate,
          String? occurredAt,
          String? status}) =>
      TodayEventLedgerData(
        recommendationId: recommendationId ?? this.recommendationId,
        event: event ?? this.event,
        clientEventId: clientEventId ?? this.clientEventId,
        kind: kind ?? this.kind,
        subjectKey: subjectKey ?? this.subjectKey,
        localDate: localDate ?? this.localDate,
        occurredAt: occurredAt ?? this.occurredAt,
        status: status ?? this.status,
      );
  TodayEventLedgerData copyWithCompanion(TodayEventLedgerCompanion data) {
    return TodayEventLedgerData(
      recommendationId: data.recommendationId.present
          ? data.recommendationId.value
          : this.recommendationId,
      event: data.event.present ? data.event.value : this.event,
      clientEventId: data.clientEventId.present
          ? data.clientEventId.value
          : this.clientEventId,
      kind: data.kind.present ? data.kind.value : this.kind,
      subjectKey:
          data.subjectKey.present ? data.subjectKey.value : this.subjectKey,
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TodayEventLedgerData(')
          ..write('recommendationId: $recommendationId, ')
          ..write('event: $event, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('kind: $kind, ')
          ..write('subjectKey: $subjectKey, ')
          ..write('localDate: $localDate, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recommendationId, event, clientEventId, kind,
      subjectKey, localDate, occurredAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TodayEventLedgerData &&
          other.recommendationId == this.recommendationId &&
          other.event == this.event &&
          other.clientEventId == this.clientEventId &&
          other.kind == this.kind &&
          other.subjectKey == this.subjectKey &&
          other.localDate == this.localDate &&
          other.occurredAt == this.occurredAt &&
          other.status == this.status);
}

class TodayEventLedgerCompanion extends UpdateCompanion<TodayEventLedgerData> {
  final Value<String> recommendationId;
  final Value<String> event;
  final Value<String> clientEventId;
  final Value<String> kind;
  final Value<String> subjectKey;
  final Value<String> localDate;
  final Value<String> occurredAt;
  final Value<String> status;
  final Value<int> rowid;
  const TodayEventLedgerCompanion({
    this.recommendationId = const Value.absent(),
    this.event = const Value.absent(),
    this.clientEventId = const Value.absent(),
    this.kind = const Value.absent(),
    this.subjectKey = const Value.absent(),
    this.localDate = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodayEventLedgerCompanion.insert({
    required String recommendationId,
    required String event,
    required String clientEventId,
    required String kind,
    required String subjectKey,
    required String localDate,
    required String occurredAt,
    required String status,
    this.rowid = const Value.absent(),
  })  : recommendationId = Value(recommendationId),
        event = Value(event),
        clientEventId = Value(clientEventId),
        kind = Value(kind),
        subjectKey = Value(subjectKey),
        localDate = Value(localDate),
        occurredAt = Value(occurredAt),
        status = Value(status);
  static Insertable<TodayEventLedgerData> custom({
    Expression<String>? recommendationId,
    Expression<String>? event,
    Expression<String>? clientEventId,
    Expression<String>? kind,
    Expression<String>? subjectKey,
    Expression<String>? localDate,
    Expression<String>? occurredAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recommendationId != null) 'recommendation_id': recommendationId,
      if (event != null) 'event': event,
      if (clientEventId != null) 'client_event_id': clientEventId,
      if (kind != null) 'kind': kind,
      if (subjectKey != null) 'subject_key': subjectKey,
      if (localDate != null) 'local_date': localDate,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodayEventLedgerCompanion copyWith(
      {Value<String>? recommendationId,
      Value<String>? event,
      Value<String>? clientEventId,
      Value<String>? kind,
      Value<String>? subjectKey,
      Value<String>? localDate,
      Value<String>? occurredAt,
      Value<String>? status,
      Value<int>? rowid}) {
    return TodayEventLedgerCompanion(
      recommendationId: recommendationId ?? this.recommendationId,
      event: event ?? this.event,
      clientEventId: clientEventId ?? this.clientEventId,
      kind: kind ?? this.kind,
      subjectKey: subjectKey ?? this.subjectKey,
      localDate: localDate ?? this.localDate,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recommendationId.present) {
      map['recommendation_id'] = Variable<String>(recommendationId.value);
    }
    if (event.present) {
      map['event'] = Variable<String>(event.value);
    }
    if (clientEventId.present) {
      map['client_event_id'] = Variable<String>(clientEventId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (subjectKey.present) {
      map['subject_key'] = Variable<String>(subjectKey.value);
    }
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<String>(occurredAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodayEventLedgerCompanion(')
          ..write('recommendationId: $recommendationId, ')
          ..write('event: $event, ')
          ..write('clientEventId: $clientEventId, ')
          ..write('kind: $kind, ')
          ..write('subjectKey: $subjectKey, ')
          ..write('localDate: $localDate, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalSessionsTable localSessions = $LocalSessionsTable(this);
  late final $LocalSessionExercisesTable localSessionExercises =
      $LocalSessionExercisesTable(this);
  late final $LocalSetLogsTable localSetLogs = $LocalSetLogsTable(this);
  late final $SyncQueueTable syncQueue = $SyncQueueTable(this);
  late final $CachedJsonTable cachedJson = $CachedJsonTable(this);
  late final $LocalFoodLogsTable localFoodLogs = $LocalFoodLogsTable(this);
  late final $NutritionSyncQueueTable nutritionSyncQueue =
      $NutritionSyncQueueTable(this);
  late final $TodayEventQueueTable todayEventQueue =
      $TodayEventQueueTable(this);
  late final $TodayEventLedgerTable todayEventLedger =
      $TodayEventLedgerTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        localSessions,
        localSessionExercises,
        localSetLogs,
        syncQueue,
        cachedJson,
        localFoodLogs,
        nutritionSyncQueue,
        todayEventQueue,
        todayEventLedger
      ];
}

typedef $$LocalSessionsTableCreateCompanionBuilder = LocalSessionsCompanion
    Function({
  required String clientSessionId,
  Value<String?> serverId,
  required String status,
  required String name,
  Value<String?> programId,
  Value<String?> programDayId,
  required String startedAt,
  Value<String?> completedAt,
  Value<String?> notes,
  required String snapshotJson,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$LocalSessionsTableUpdateCompanionBuilder = LocalSessionsCompanion
    Function({
  Value<String> clientSessionId,
  Value<String?> serverId,
  Value<String> status,
  Value<String> name,
  Value<String?> programId,
  Value<String?> programDayId,
  Value<String> startedAt,
  Value<String?> completedAt,
  Value<String?> notes,
  Value<String> snapshotJson,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$LocalSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get programId => $composableBuilder(
      column: $table.programId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get programDayId => $composableBuilder(
      column: $table.programDayId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get programId => $composableBuilder(
      column: $table.programId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get programDayId => $composableBuilder(
      column: $table.programDayId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get programId =>
      $composableBuilder(column: $table.programId, builder: (column) => column);

  GeneratedColumn<String> get programDayId => $composableBuilder(
      column: $table.programDayId, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSessionsTable,
    LocalSession,
    $$LocalSessionsTableFilterComposer,
    $$LocalSessionsTableOrderingComposer,
    $$LocalSessionsTableAnnotationComposer,
    $$LocalSessionsTableCreateCompanionBuilder,
    $$LocalSessionsTableUpdateCompanionBuilder,
    (
      LocalSession,
      BaseReferences<_$AppDatabase, $LocalSessionsTable, LocalSession>
    ),
    LocalSession,
    PrefetchHooks Function()> {
  $$LocalSessionsTableTableManager(_$AppDatabase db, $LocalSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientSessionId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> programId = const Value.absent(),
            Value<String?> programDayId = const Value.absent(),
            Value<String> startedAt = const Value.absent(),
            Value<String?> completedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String> snapshotJson = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSessionsCompanion(
            clientSessionId: clientSessionId,
            serverId: serverId,
            status: status,
            name: name,
            programId: programId,
            programDayId: programDayId,
            startedAt: startedAt,
            completedAt: completedAt,
            notes: notes,
            snapshotJson: snapshotJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientSessionId,
            Value<String?> serverId = const Value.absent(),
            required String status,
            required String name,
            Value<String?> programId = const Value.absent(),
            Value<String?> programDayId = const Value.absent(),
            required String startedAt,
            Value<String?> completedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required String snapshotJson,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSessionsCompanion.insert(
            clientSessionId: clientSessionId,
            serverId: serverId,
            status: status,
            name: name,
            programId: programId,
            programDayId: programDayId,
            startedAt: startedAt,
            completedAt: completedAt,
            notes: notes,
            snapshotJson: snapshotJson,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalSessionsTable,
    LocalSession,
    $$LocalSessionsTableFilterComposer,
    $$LocalSessionsTableOrderingComposer,
    $$LocalSessionsTableAnnotationComposer,
    $$LocalSessionsTableCreateCompanionBuilder,
    $$LocalSessionsTableUpdateCompanionBuilder,
    (
      LocalSession,
      BaseReferences<_$AppDatabase, $LocalSessionsTable, LocalSession>
    ),
    LocalSession,
    PrefetchHooks Function()>;
typedef $$LocalSessionExercisesTableCreateCompanionBuilder
    = LocalSessionExercisesCompanion Function({
  required String clientExerciseId,
  required String clientSessionId,
  Value<String?> serverId,
  required String exerciseId,
  Value<String?> plannedExerciseId,
  required int orderIndex,
  Value<int?> supersetGroup,
  Value<bool> removed,
  required String exerciseJson,
  Value<int> rowid,
});
typedef $$LocalSessionExercisesTableUpdateCompanionBuilder
    = LocalSessionExercisesCompanion Function({
  Value<String> clientExerciseId,
  Value<String> clientSessionId,
  Value<String?> serverId,
  Value<String> exerciseId,
  Value<String?> plannedExerciseId,
  Value<int> orderIndex,
  Value<int?> supersetGroup,
  Value<bool> removed,
  Value<String> exerciseJson,
  Value<int> rowid,
});

class $$LocalSessionExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSessionExercisesTable> {
  $$LocalSessionExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exerciseId => $composableBuilder(
      column: $table.exerciseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plannedExerciseId => $composableBuilder(
      column: $table.plannedExerciseId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get supersetGroup => $composableBuilder(
      column: $table.supersetGroup, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get removed => $composableBuilder(
      column: $table.removed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exerciseJson => $composableBuilder(
      column: $table.exerciseJson, builder: (column) => ColumnFilters(column));
}

class $$LocalSessionExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSessionExercisesTable> {
  $$LocalSessionExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exerciseId => $composableBuilder(
      column: $table.exerciseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plannedExerciseId => $composableBuilder(
      column: $table.plannedExerciseId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get supersetGroup => $composableBuilder(
      column: $table.supersetGroup,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get removed => $composableBuilder(
      column: $table.removed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exerciseJson => $composableBuilder(
      column: $table.exerciseJson,
      builder: (column) => ColumnOrderings(column));
}

class $$LocalSessionExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSessionExercisesTable> {
  $$LocalSessionExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId, builder: (column) => column);

  GeneratedColumn<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get exerciseId => $composableBuilder(
      column: $table.exerciseId, builder: (column) => column);

  GeneratedColumn<String> get plannedExerciseId => $composableBuilder(
      column: $table.plannedExerciseId, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
      column: $table.orderIndex, builder: (column) => column);

  GeneratedColumn<int> get supersetGroup => $composableBuilder(
      column: $table.supersetGroup, builder: (column) => column);

  GeneratedColumn<bool> get removed =>
      $composableBuilder(column: $table.removed, builder: (column) => column);

  GeneratedColumn<String> get exerciseJson => $composableBuilder(
      column: $table.exerciseJson, builder: (column) => column);
}

class $$LocalSessionExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSessionExercisesTable,
    LocalSessionExercise,
    $$LocalSessionExercisesTableFilterComposer,
    $$LocalSessionExercisesTableOrderingComposer,
    $$LocalSessionExercisesTableAnnotationComposer,
    $$LocalSessionExercisesTableCreateCompanionBuilder,
    $$LocalSessionExercisesTableUpdateCompanionBuilder,
    (
      LocalSessionExercise,
      BaseReferences<_$AppDatabase, $LocalSessionExercisesTable,
          LocalSessionExercise>
    ),
    LocalSessionExercise,
    PrefetchHooks Function()> {
  $$LocalSessionExercisesTableTableManager(
      _$AppDatabase db, $LocalSessionExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSessionExercisesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSessionExercisesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSessionExercisesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientExerciseId = const Value.absent(),
            Value<String> clientSessionId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> exerciseId = const Value.absent(),
            Value<String?> plannedExerciseId = const Value.absent(),
            Value<int> orderIndex = const Value.absent(),
            Value<int?> supersetGroup = const Value.absent(),
            Value<bool> removed = const Value.absent(),
            Value<String> exerciseJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSessionExercisesCompanion(
            clientExerciseId: clientExerciseId,
            clientSessionId: clientSessionId,
            serverId: serverId,
            exerciseId: exerciseId,
            plannedExerciseId: plannedExerciseId,
            orderIndex: orderIndex,
            supersetGroup: supersetGroup,
            removed: removed,
            exerciseJson: exerciseJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientExerciseId,
            required String clientSessionId,
            Value<String?> serverId = const Value.absent(),
            required String exerciseId,
            Value<String?> plannedExerciseId = const Value.absent(),
            required int orderIndex,
            Value<int?> supersetGroup = const Value.absent(),
            Value<bool> removed = const Value.absent(),
            required String exerciseJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSessionExercisesCompanion.insert(
            clientExerciseId: clientExerciseId,
            clientSessionId: clientSessionId,
            serverId: serverId,
            exerciseId: exerciseId,
            plannedExerciseId: plannedExerciseId,
            orderIndex: orderIndex,
            supersetGroup: supersetGroup,
            removed: removed,
            exerciseJson: exerciseJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSessionExercisesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $LocalSessionExercisesTable,
        LocalSessionExercise,
        $$LocalSessionExercisesTableFilterComposer,
        $$LocalSessionExercisesTableOrderingComposer,
        $$LocalSessionExercisesTableAnnotationComposer,
        $$LocalSessionExercisesTableCreateCompanionBuilder,
        $$LocalSessionExercisesTableUpdateCompanionBuilder,
        (
          LocalSessionExercise,
          BaseReferences<_$AppDatabase, $LocalSessionExercisesTable,
              LocalSessionExercise>
        ),
        LocalSessionExercise,
        PrefetchHooks Function()>;
typedef $$LocalSetLogsTableCreateCompanionBuilder = LocalSetLogsCompanion
    Function({
  required String clientSetId,
  required String clientExerciseId,
  Value<String?> serverId,
  required int setIndex,
  required String setType,
  Value<double?> weightKg,
  required int reps,
  Value<int?> rir,
  required String loggedAt,
  Value<String?> plannedSetId,
  Value<bool> isPr,
  Value<bool> deleted,
  Value<int> rowid,
});
typedef $$LocalSetLogsTableUpdateCompanionBuilder = LocalSetLogsCompanion
    Function({
  Value<String> clientSetId,
  Value<String> clientExerciseId,
  Value<String?> serverId,
  Value<int> setIndex,
  Value<String> setType,
  Value<double?> weightKg,
  Value<int> reps,
  Value<int?> rir,
  Value<String> loggedAt,
  Value<String?> plannedSetId,
  Value<bool> isPr,
  Value<bool> deleted,
  Value<int> rowid,
});

class $$LocalSetLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSetLogsTable> {
  $$LocalSetLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientSetId => $composableBuilder(
      column: $table.clientSetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get setType => $composableBuilder(
      column: $table.setType, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get plannedSetId => $composableBuilder(
      column: $table.plannedSetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPr => $composableBuilder(
      column: $table.isPr, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));
}

class $$LocalSetLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSetLogsTable> {
  $$LocalSetLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientSetId => $composableBuilder(
      column: $table.clientSetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get setType => $composableBuilder(
      column: $table.setType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rir => $composableBuilder(
      column: $table.rir, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get plannedSetId => $composableBuilder(
      column: $table.plannedSetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPr => $composableBuilder(
      column: $table.isPr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));
}

class $$LocalSetLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSetLogsTable> {
  $$LocalSetLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientSetId => $composableBuilder(
      column: $table.clientSetId, builder: (column) => column);

  GeneratedColumn<String> get clientExerciseId => $composableBuilder(
      column: $table.clientExerciseId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<String> get setType =>
      $composableBuilder(column: $table.setType, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<int> get rir =>
      $composableBuilder(column: $table.rir, builder: (column) => column);

  GeneratedColumn<String> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get plannedSetId => $composableBuilder(
      column: $table.plannedSetId, builder: (column) => column);

  GeneratedColumn<bool> get isPr =>
      $composableBuilder(column: $table.isPr, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);
}

class $$LocalSetLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalSetLogsTable,
    LocalSetLog,
    $$LocalSetLogsTableFilterComposer,
    $$LocalSetLogsTableOrderingComposer,
    $$LocalSetLogsTableAnnotationComposer,
    $$LocalSetLogsTableCreateCompanionBuilder,
    $$LocalSetLogsTableUpdateCompanionBuilder,
    (
      LocalSetLog,
      BaseReferences<_$AppDatabase, $LocalSetLogsTable, LocalSetLog>
    ),
    LocalSetLog,
    PrefetchHooks Function()> {
  $$LocalSetLogsTableTableManager(_$AppDatabase db, $LocalSetLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSetLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSetLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSetLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientSetId = const Value.absent(),
            Value<String> clientExerciseId = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<int> setIndex = const Value.absent(),
            Value<String> setType = const Value.absent(),
            Value<double?> weightKg = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<int?> rir = const Value.absent(),
            Value<String> loggedAt = const Value.absent(),
            Value<String?> plannedSetId = const Value.absent(),
            Value<bool> isPr = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSetLogsCompanion(
            clientSetId: clientSetId,
            clientExerciseId: clientExerciseId,
            serverId: serverId,
            setIndex: setIndex,
            setType: setType,
            weightKg: weightKg,
            reps: reps,
            rir: rir,
            loggedAt: loggedAt,
            plannedSetId: plannedSetId,
            isPr: isPr,
            deleted: deleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientSetId,
            required String clientExerciseId,
            Value<String?> serverId = const Value.absent(),
            required int setIndex,
            required String setType,
            Value<double?> weightKg = const Value.absent(),
            required int reps,
            Value<int?> rir = const Value.absent(),
            required String loggedAt,
            Value<String?> plannedSetId = const Value.absent(),
            Value<bool> isPr = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalSetLogsCompanion.insert(
            clientSetId: clientSetId,
            clientExerciseId: clientExerciseId,
            serverId: serverId,
            setIndex: setIndex,
            setType: setType,
            weightKg: weightKg,
            reps: reps,
            rir: rir,
            loggedAt: loggedAt,
            plannedSetId: plannedSetId,
            isPr: isPr,
            deleted: deleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalSetLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalSetLogsTable,
    LocalSetLog,
    $$LocalSetLogsTableFilterComposer,
    $$LocalSetLogsTableOrderingComposer,
    $$LocalSetLogsTableAnnotationComposer,
    $$LocalSetLogsTableCreateCompanionBuilder,
    $$LocalSetLogsTableUpdateCompanionBuilder,
    (
      LocalSetLog,
      BaseReferences<_$AppDatabase, $LocalSetLogsTable, LocalSetLog>
    ),
    LocalSetLog,
    PrefetchHooks Function()>;
typedef $$SyncQueueTableCreateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  required String kind,
  required String clientSessionId,
  Value<String?> clientKey,
  required String payloadJson,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  Value<bool> parked,
  required String createdAt,
});
typedef $$SyncQueueTableUpdateCompanionBuilder = SyncQueueCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> clientSessionId,
  Value<String?> clientKey,
  Value<String> payloadJson,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  Value<bool> parked,
  Value<String> createdAt,
});

class $$SyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientKey => $composableBuilder(
      column: $table.clientKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get parked => $composableBuilder(
      column: $table.parked, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientKey => $composableBuilder(
      column: $table.clientKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get parked => $composableBuilder(
      column: $table.parked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueTable> {
  $$SyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get clientSessionId => $composableBuilder(
      column: $table.clientSessionId, builder: (column) => column);

  GeneratedColumn<String> get clientKey =>
      $composableBuilder(column: $table.clientKey, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get parked =>
      $composableBuilder(column: $table.parked, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()> {
  $$SyncQueueTableTableManager(_$AppDatabase db, $SyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> clientSessionId = const Value.absent(),
            Value<String?> clientKey = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> parked = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
          }) =>
              SyncQueueCompanion(
            id: id,
            kind: kind,
            clientSessionId: clientSessionId,
            clientKey: clientKey,
            payloadJson: payloadJson,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            parked: parked,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String kind,
            required String clientSessionId,
            Value<String?> clientKey = const Value.absent(),
            required String payloadJson,
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> parked = const Value.absent(),
            required String createdAt,
          }) =>
              SyncQueueCompanion.insert(
            id: id,
            kind: kind,
            clientSessionId: clientSessionId,
            clientKey: clientKey,
            payloadJson: payloadJson,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            parked: parked,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueTable,
    SyncQueueData,
    $$SyncQueueTableFilterComposer,
    $$SyncQueueTableOrderingComposer,
    $$SyncQueueTableAnnotationComposer,
    $$SyncQueueTableCreateCompanionBuilder,
    $$SyncQueueTableUpdateCompanionBuilder,
    (
      SyncQueueData,
      BaseReferences<_$AppDatabase, $SyncQueueTable, SyncQueueData>
    ),
    SyncQueueData,
    PrefetchHooks Function()>;
typedef $$CachedJsonTableCreateCompanionBuilder = CachedJsonCompanion Function({
  required String key,
  required String json,
  required String storedAt,
  Value<int> rowid,
});
typedef $$CachedJsonTableUpdateCompanionBuilder = CachedJsonCompanion Function({
  Value<String> key,
  Value<String> json,
  Value<String> storedAt,
  Value<int> rowid,
});

class $$CachedJsonTableFilterComposer
    extends Composer<_$AppDatabase, $CachedJsonTable> {
  $$CachedJsonTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storedAt => $composableBuilder(
      column: $table.storedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedJsonTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedJsonTable> {
  $$CachedJsonTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storedAt => $composableBuilder(
      column: $table.storedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedJsonTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedJsonTable> {
  $$CachedJsonTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get storedAt =>
      $composableBuilder(column: $table.storedAt, builder: (column) => column);
}

class $$CachedJsonTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedJsonTable,
    CachedJsonData,
    $$CachedJsonTableFilterComposer,
    $$CachedJsonTableOrderingComposer,
    $$CachedJsonTableAnnotationComposer,
    $$CachedJsonTableCreateCompanionBuilder,
    $$CachedJsonTableUpdateCompanionBuilder,
    (
      CachedJsonData,
      BaseReferences<_$AppDatabase, $CachedJsonTable, CachedJsonData>
    ),
    CachedJsonData,
    PrefetchHooks Function()> {
  $$CachedJsonTableTableManager(_$AppDatabase db, $CachedJsonTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedJsonTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedJsonTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedJsonTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<String> storedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedJsonCompanion(
            key: key,
            json: json,
            storedAt: storedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String json,
            required String storedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedJsonCompanion.insert(
            key: key,
            json: json,
            storedAt: storedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedJsonTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedJsonTable,
    CachedJsonData,
    $$CachedJsonTableFilterComposer,
    $$CachedJsonTableOrderingComposer,
    $$CachedJsonTableAnnotationComposer,
    $$CachedJsonTableCreateCompanionBuilder,
    $$CachedJsonTableUpdateCompanionBuilder,
    (
      CachedJsonData,
      BaseReferences<_$AppDatabase, $CachedJsonTable, CachedJsonData>
    ),
    CachedJsonData,
    PrefetchHooks Function()>;
typedef $$LocalFoodLogsTableCreateCompanionBuilder = LocalFoodLogsCompanion
    Function({
  required String clientLogId,
  required String localDate,
  required String mealSlot,
  required String loggedAt,
  required String requestJson,
  required String previewJson,
  required String createdAt,
  Value<int> rowid,
});
typedef $$LocalFoodLogsTableUpdateCompanionBuilder = LocalFoodLogsCompanion
    Function({
  Value<String> clientLogId,
  Value<String> localDate,
  Value<String> mealSlot,
  Value<String> loggedAt,
  Value<String> requestJson,
  Value<String> previewJson,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$LocalFoodLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalFoodLogsTable> {
  $$LocalFoodLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mealSlot => $composableBuilder(
      column: $table.mealSlot, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requestJson => $composableBuilder(
      column: $table.requestJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get previewJson => $composableBuilder(
      column: $table.previewJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalFoodLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalFoodLogsTable> {
  $$LocalFoodLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mealSlot => $composableBuilder(
      column: $table.mealSlot, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get loggedAt => $composableBuilder(
      column: $table.loggedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requestJson => $composableBuilder(
      column: $table.requestJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get previewJson => $composableBuilder(
      column: $table.previewJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalFoodLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalFoodLogsTable> {
  $$LocalFoodLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get mealSlot =>
      $composableBuilder(column: $table.mealSlot, builder: (column) => column);

  GeneratedColumn<String> get loggedAt =>
      $composableBuilder(column: $table.loggedAt, builder: (column) => column);

  GeneratedColumn<String> get requestJson => $composableBuilder(
      column: $table.requestJson, builder: (column) => column);

  GeneratedColumn<String> get previewJson => $composableBuilder(
      column: $table.previewJson, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalFoodLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalFoodLogsTable,
    LocalFoodLog,
    $$LocalFoodLogsTableFilterComposer,
    $$LocalFoodLogsTableOrderingComposer,
    $$LocalFoodLogsTableAnnotationComposer,
    $$LocalFoodLogsTableCreateCompanionBuilder,
    $$LocalFoodLogsTableUpdateCompanionBuilder,
    (
      LocalFoodLog,
      BaseReferences<_$AppDatabase, $LocalFoodLogsTable, LocalFoodLog>
    ),
    LocalFoodLog,
    PrefetchHooks Function()> {
  $$LocalFoodLogsTableTableManager(_$AppDatabase db, $LocalFoodLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalFoodLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalFoodLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalFoodLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientLogId = const Value.absent(),
            Value<String> localDate = const Value.absent(),
            Value<String> mealSlot = const Value.absent(),
            Value<String> loggedAt = const Value.absent(),
            Value<String> requestJson = const Value.absent(),
            Value<String> previewJson = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalFoodLogsCompanion(
            clientLogId: clientLogId,
            localDate: localDate,
            mealSlot: mealSlot,
            loggedAt: loggedAt,
            requestJson: requestJson,
            previewJson: previewJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String clientLogId,
            required String localDate,
            required String mealSlot,
            required String loggedAt,
            required String requestJson,
            required String previewJson,
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalFoodLogsCompanion.insert(
            clientLogId: clientLogId,
            localDate: localDate,
            mealSlot: mealSlot,
            loggedAt: loggedAt,
            requestJson: requestJson,
            previewJson: previewJson,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalFoodLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalFoodLogsTable,
    LocalFoodLog,
    $$LocalFoodLogsTableFilterComposer,
    $$LocalFoodLogsTableOrderingComposer,
    $$LocalFoodLogsTableAnnotationComposer,
    $$LocalFoodLogsTableCreateCompanionBuilder,
    $$LocalFoodLogsTableUpdateCompanionBuilder,
    (
      LocalFoodLog,
      BaseReferences<_$AppDatabase, $LocalFoodLogsTable, LocalFoodLog>
    ),
    LocalFoodLog,
    PrefetchHooks Function()>;
typedef $$NutritionSyncQueueTableCreateCompanionBuilder
    = NutritionSyncQueueCompanion Function({
  Value<int> id,
  required String kind,
  required String clientLogId,
  required String payloadJson,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  Value<bool> parked,
  required String createdAt,
});
typedef $$NutritionSyncQueueTableUpdateCompanionBuilder
    = NutritionSyncQueueCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> clientLogId,
  Value<String> payloadJson,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  Value<bool> parked,
  Value<String> createdAt,
});

class $$NutritionSyncQueueTableFilterComposer
    extends Composer<_$AppDatabase, $NutritionSyncQueueTable> {
  $$NutritionSyncQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get parked => $composableBuilder(
      column: $table.parked, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$NutritionSyncQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $NutritionSyncQueueTable> {
  $$NutritionSyncQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get parked => $composableBuilder(
      column: $table.parked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$NutritionSyncQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $NutritionSyncQueueTable> {
  $$NutritionSyncQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get clientLogId => $composableBuilder(
      column: $table.clientLogId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
      column: $table.payloadJson, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get parked =>
      $composableBuilder(column: $table.parked, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$NutritionSyncQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NutritionSyncQueueTable,
    NutritionSyncQueueData,
    $$NutritionSyncQueueTableFilterComposer,
    $$NutritionSyncQueueTableOrderingComposer,
    $$NutritionSyncQueueTableAnnotationComposer,
    $$NutritionSyncQueueTableCreateCompanionBuilder,
    $$NutritionSyncQueueTableUpdateCompanionBuilder,
    (
      NutritionSyncQueueData,
      BaseReferences<_$AppDatabase, $NutritionSyncQueueTable,
          NutritionSyncQueueData>
    ),
    NutritionSyncQueueData,
    PrefetchHooks Function()> {
  $$NutritionSyncQueueTableTableManager(
      _$AppDatabase db, $NutritionSyncQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NutritionSyncQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NutritionSyncQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NutritionSyncQueueTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> clientLogId = const Value.absent(),
            Value<String> payloadJson = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> parked = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
          }) =>
              NutritionSyncQueueCompanion(
            id: id,
            kind: kind,
            clientLogId: clientLogId,
            payloadJson: payloadJson,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            parked: parked,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String kind,
            required String clientLogId,
            required String payloadJson,
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<bool> parked = const Value.absent(),
            required String createdAt,
          }) =>
              NutritionSyncQueueCompanion.insert(
            id: id,
            kind: kind,
            clientLogId: clientLogId,
            payloadJson: payloadJson,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            parked: parked,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NutritionSyncQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NutritionSyncQueueTable,
    NutritionSyncQueueData,
    $$NutritionSyncQueueTableFilterComposer,
    $$NutritionSyncQueueTableOrderingComposer,
    $$NutritionSyncQueueTableAnnotationComposer,
    $$NutritionSyncQueueTableCreateCompanionBuilder,
    $$NutritionSyncQueueTableUpdateCompanionBuilder,
    (
      NutritionSyncQueueData,
      BaseReferences<_$AppDatabase, $NutritionSyncQueueTable,
          NutritionSyncQueueData>
    ),
    NutritionSyncQueueData,
    PrefetchHooks Function()>;
typedef $$TodayEventQueueTableCreateCompanionBuilder = TodayEventQueueCompanion
    Function({
  Value<int> id,
  required String clientEventId,
  required String recommendationId,
  required String event,
  required String occurredAt,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  required String createdAt,
});
typedef $$TodayEventQueueTableUpdateCompanionBuilder = TodayEventQueueCompanion
    Function({
  Value<int> id,
  Value<String> clientEventId,
  Value<String> recommendationId,
  Value<String> event,
  Value<String> occurredAt,
  Value<int> attempts,
  Value<String?> nextAttemptAt,
  Value<String?> lastError,
  Value<String> createdAt,
});

class $$TodayEventQueueTableFilterComposer
    extends Composer<_$AppDatabase, $TodayEventQueueTable> {
  $$TodayEventQueueTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$TodayEventQueueTableOrderingComposer
    extends Composer<_$AppDatabase, $TodayEventQueueTable> {
  $$TodayEventQueueTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TodayEventQueueTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodayEventQueueTable> {
  $$TodayEventQueueTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId, builder: (column) => column);

  GeneratedColumn<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get nextAttemptAt => $composableBuilder(
      column: $table.nextAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TodayEventQueueTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TodayEventQueueTable,
    TodayEventQueueData,
    $$TodayEventQueueTableFilterComposer,
    $$TodayEventQueueTableOrderingComposer,
    $$TodayEventQueueTableAnnotationComposer,
    $$TodayEventQueueTableCreateCompanionBuilder,
    $$TodayEventQueueTableUpdateCompanionBuilder,
    (
      TodayEventQueueData,
      BaseReferences<_$AppDatabase, $TodayEventQueueTable, TodayEventQueueData>
    ),
    TodayEventQueueData,
    PrefetchHooks Function()> {
  $$TodayEventQueueTableTableManager(
      _$AppDatabase db, $TodayEventQueueTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodayEventQueueTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodayEventQueueTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodayEventQueueTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> clientEventId = const Value.absent(),
            Value<String> recommendationId = const Value.absent(),
            Value<String> event = const Value.absent(),
            Value<String> occurredAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
          }) =>
              TodayEventQueueCompanion(
            id: id,
            clientEventId: clientEventId,
            recommendationId: recommendationId,
            event: event,
            occurredAt: occurredAt,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String clientEventId,
            required String recommendationId,
            required String event,
            required String occurredAt,
            Value<int> attempts = const Value.absent(),
            Value<String?> nextAttemptAt = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required String createdAt,
          }) =>
              TodayEventQueueCompanion.insert(
            id: id,
            clientEventId: clientEventId,
            recommendationId: recommendationId,
            event: event,
            occurredAt: occurredAt,
            attempts: attempts,
            nextAttemptAt: nextAttemptAt,
            lastError: lastError,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TodayEventQueueTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TodayEventQueueTable,
    TodayEventQueueData,
    $$TodayEventQueueTableFilterComposer,
    $$TodayEventQueueTableOrderingComposer,
    $$TodayEventQueueTableAnnotationComposer,
    $$TodayEventQueueTableCreateCompanionBuilder,
    $$TodayEventQueueTableUpdateCompanionBuilder,
    (
      TodayEventQueueData,
      BaseReferences<_$AppDatabase, $TodayEventQueueTable, TodayEventQueueData>
    ),
    TodayEventQueueData,
    PrefetchHooks Function()>;
typedef $$TodayEventLedgerTableCreateCompanionBuilder
    = TodayEventLedgerCompanion Function({
  required String recommendationId,
  required String event,
  required String clientEventId,
  required String kind,
  required String subjectKey,
  required String localDate,
  required String occurredAt,
  required String status,
  Value<int> rowid,
});
typedef $$TodayEventLedgerTableUpdateCompanionBuilder
    = TodayEventLedgerCompanion Function({
  Value<String> recommendationId,
  Value<String> event,
  Value<String> clientEventId,
  Value<String> kind,
  Value<String> subjectKey,
  Value<String> localDate,
  Value<String> occurredAt,
  Value<String> status,
  Value<int> rowid,
});

class $$TodayEventLedgerTableFilterComposer
    extends Composer<_$AppDatabase, $TodayEventLedgerTable> {
  $$TodayEventLedgerTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subjectKey => $composableBuilder(
      column: $table.subjectKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$TodayEventLedgerTableOrderingComposer
    extends Composer<_$AppDatabase, $TodayEventLedgerTable> {
  $$TodayEventLedgerTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get event => $composableBuilder(
      column: $table.event, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subjectKey => $composableBuilder(
      column: $table.subjectKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$TodayEventLedgerTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodayEventLedgerTable> {
  $$TodayEventLedgerTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recommendationId => $composableBuilder(
      column: $table.recommendationId, builder: (column) => column);

  GeneratedColumn<String> get event =>
      $composableBuilder(column: $table.event, builder: (column) => column);

  GeneratedColumn<String> get clientEventId => $composableBuilder(
      column: $table.clientEventId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subjectKey => $composableBuilder(
      column: $table.subjectKey, builder: (column) => column);

  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$TodayEventLedgerTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TodayEventLedgerTable,
    TodayEventLedgerData,
    $$TodayEventLedgerTableFilterComposer,
    $$TodayEventLedgerTableOrderingComposer,
    $$TodayEventLedgerTableAnnotationComposer,
    $$TodayEventLedgerTableCreateCompanionBuilder,
    $$TodayEventLedgerTableUpdateCompanionBuilder,
    (
      TodayEventLedgerData,
      BaseReferences<_$AppDatabase, $TodayEventLedgerTable,
          TodayEventLedgerData>
    ),
    TodayEventLedgerData,
    PrefetchHooks Function()> {
  $$TodayEventLedgerTableTableManager(
      _$AppDatabase db, $TodayEventLedgerTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodayEventLedgerTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodayEventLedgerTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodayEventLedgerTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> recommendationId = const Value.absent(),
            Value<String> event = const Value.absent(),
            Value<String> clientEventId = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> subjectKey = const Value.absent(),
            Value<String> localDate = const Value.absent(),
            Value<String> occurredAt = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TodayEventLedgerCompanion(
            recommendationId: recommendationId,
            event: event,
            clientEventId: clientEventId,
            kind: kind,
            subjectKey: subjectKey,
            localDate: localDate,
            occurredAt: occurredAt,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String recommendationId,
            required String event,
            required String clientEventId,
            required String kind,
            required String subjectKey,
            required String localDate,
            required String occurredAt,
            required String status,
            Value<int> rowid = const Value.absent(),
          }) =>
              TodayEventLedgerCompanion.insert(
            recommendationId: recommendationId,
            event: event,
            clientEventId: clientEventId,
            kind: kind,
            subjectKey: subjectKey,
            localDate: localDate,
            occurredAt: occurredAt,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TodayEventLedgerTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TodayEventLedgerTable,
    TodayEventLedgerData,
    $$TodayEventLedgerTableFilterComposer,
    $$TodayEventLedgerTableOrderingComposer,
    $$TodayEventLedgerTableAnnotationComposer,
    $$TodayEventLedgerTableCreateCompanionBuilder,
    $$TodayEventLedgerTableUpdateCompanionBuilder,
    (
      TodayEventLedgerData,
      BaseReferences<_$AppDatabase, $TodayEventLedgerTable,
          TodayEventLedgerData>
    ),
    TodayEventLedgerData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalSessionsTableTableManager get localSessions =>
      $$LocalSessionsTableTableManager(_db, _db.localSessions);
  $$LocalSessionExercisesTableTableManager get localSessionExercises =>
      $$LocalSessionExercisesTableTableManager(_db, _db.localSessionExercises);
  $$LocalSetLogsTableTableManager get localSetLogs =>
      $$LocalSetLogsTableTableManager(_db, _db.localSetLogs);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db, _db.syncQueue);
  $$CachedJsonTableTableManager get cachedJson =>
      $$CachedJsonTableTableManager(_db, _db.cachedJson);
  $$LocalFoodLogsTableTableManager get localFoodLogs =>
      $$LocalFoodLogsTableTableManager(_db, _db.localFoodLogs);
  $$NutritionSyncQueueTableTableManager get nutritionSyncQueue =>
      $$NutritionSyncQueueTableTableManager(_db, _db.nutritionSyncQueue);
  $$TodayEventQueueTableTableManager get todayEventQueue =>
      $$TodayEventQueueTableTableManager(_db, _db.todayEventQueue);
  $$TodayEventLedgerTableTableManager get todayEventLedger =>
      $$TodayEventLedgerTableTableManager(_db, _db.todayEventLedger);
}
