// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FeedingsTable extends Feedings
    with TableInfo<$FeedingsTable, StoredFeeding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startIsoMeta =
      const VerificationMeta('startIso');
  @override
  late final GeneratedColumn<String> startIso = GeneratedColumn<String>(
      'start_iso', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endIsoMeta = const VerificationMeta('endIso');
  @override
  late final GeneratedColumn<String> endIso = GeneratedColumn<String>(
      'end_iso', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _leftMsMeta = const VerificationMeta('leftMs');
  @override
  late final GeneratedColumn<int> leftMs = GeneratedColumn<int>(
      'left_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rightMsMeta =
      const VerificationMeta('rightMs');
  @override
  late final GeneratedColumn<int> rightMs = GeneratedColumn<int>(
      'right_ms', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _endSideMeta =
      const VerificationMeta('endSide');
  @override
  late final GeneratedColumn<String> endSide = GeneratedColumn<String>(
      'end_side', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _amountMlMeta =
      const VerificationMeta('amountMl');
  @override
  late final GeneratedColumn<int> amountMl = GeneratedColumn<int>(
      'amount_ml', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _utcOffsetMinMeta =
      const VerificationMeta('utcOffsetMin');
  @override
  late final GeneratedColumn<int> utcOffsetMin = GeneratedColumn<int>(
      'utc_offset_min', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        type,
        startIso,
        endIso,
        leftMs,
        rightMs,
        endSide,
        amountMl,
        notes,
        updatedAt,
        utcOffsetMin
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feedings';
  @override
  VerificationContext validateIntegrity(Insertable<StoredFeeding> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('start_iso')) {
      context.handle(_startIsoMeta,
          startIso.isAcceptableOrUnknown(data['start_iso']!, _startIsoMeta));
    } else if (isInserting) {
      context.missing(_startIsoMeta);
    }
    if (data.containsKey('end_iso')) {
      context.handle(_endIsoMeta,
          endIso.isAcceptableOrUnknown(data['end_iso']!, _endIsoMeta));
    } else if (isInserting) {
      context.missing(_endIsoMeta);
    }
    if (data.containsKey('left_ms')) {
      context.handle(_leftMsMeta,
          leftMs.isAcceptableOrUnknown(data['left_ms']!, _leftMsMeta));
    }
    if (data.containsKey('right_ms')) {
      context.handle(_rightMsMeta,
          rightMs.isAcceptableOrUnknown(data['right_ms']!, _rightMsMeta));
    }
    if (data.containsKey('end_side')) {
      context.handle(_endSideMeta,
          endSide.isAcceptableOrUnknown(data['end_side']!, _endSideMeta));
    }
    if (data.containsKey('amount_ml')) {
      context.handle(_amountMlMeta,
          amountMl.isAcceptableOrUnknown(data['amount_ml']!, _amountMlMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('utc_offset_min')) {
      context.handle(
          _utcOffsetMinMeta,
          utcOffsetMin.isAcceptableOrUnknown(
              data['utc_offset_min']!, _utcOffsetMinMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredFeeding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredFeeding(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      startIso: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_iso'])!,
      endIso: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_iso'])!,
      leftMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}left_ms'])!,
      rightMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}right_ms'])!,
      endSide: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_side']),
      amountMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_ml'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at']),
      utcOffsetMin: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}utc_offset_min']),
    );
  }

  @override
  $FeedingsTable createAlias(String alias) {
    return $FeedingsTable(attachedDatabase, alias);
  }
}

class StoredFeeding extends DataClass implements Insertable<StoredFeeding> {
  final String id;
  final String type;
  final String startIso;
  final String endIso;
  final int leftMs;
  final int rightMs;
  final String? endSide;
  final int amountMl;
  final String notes;
  final String? updatedAt;
  final int? utcOffsetMin;
  const StoredFeeding(
      {required this.id,
      required this.type,
      required this.startIso,
      required this.endIso,
      required this.leftMs,
      required this.rightMs,
      this.endSide,
      required this.amountMl,
      required this.notes,
      this.updatedAt,
      this.utcOffsetMin});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['start_iso'] = Variable<String>(startIso);
    map['end_iso'] = Variable<String>(endIso);
    map['left_ms'] = Variable<int>(leftMs);
    map['right_ms'] = Variable<int>(rightMs);
    if (!nullToAbsent || endSide != null) {
      map['end_side'] = Variable<String>(endSide);
    }
    map['amount_ml'] = Variable<int>(amountMl);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || utcOffsetMin != null) {
      map['utc_offset_min'] = Variable<int>(utcOffsetMin);
    }
    return map;
  }

  FeedingsCompanion toCompanion(bool nullToAbsent) {
    return FeedingsCompanion(
      id: Value(id),
      type: Value(type),
      startIso: Value(startIso),
      endIso: Value(endIso),
      leftMs: Value(leftMs),
      rightMs: Value(rightMs),
      endSide: endSide == null && nullToAbsent
          ? const Value.absent()
          : Value(endSide),
      amountMl: Value(amountMl),
      notes: Value(notes),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      utcOffsetMin: utcOffsetMin == null && nullToAbsent
          ? const Value.absent()
          : Value(utcOffsetMin),
    );
  }

  factory StoredFeeding.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredFeeding(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      startIso: serializer.fromJson<String>(json['startIso']),
      endIso: serializer.fromJson<String>(json['endIso']),
      leftMs: serializer.fromJson<int>(json['leftMs']),
      rightMs: serializer.fromJson<int>(json['rightMs']),
      endSide: serializer.fromJson<String?>(json['endSide']),
      amountMl: serializer.fromJson<int>(json['amountMl']),
      notes: serializer.fromJson<String>(json['notes']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
      utcOffsetMin: serializer.fromJson<int?>(json['utcOffsetMin']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'startIso': serializer.toJson<String>(startIso),
      'endIso': serializer.toJson<String>(endIso),
      'leftMs': serializer.toJson<int>(leftMs),
      'rightMs': serializer.toJson<int>(rightMs),
      'endSide': serializer.toJson<String?>(endSide),
      'amountMl': serializer.toJson<int>(amountMl),
      'notes': serializer.toJson<String>(notes),
      'updatedAt': serializer.toJson<String?>(updatedAt),
      'utcOffsetMin': serializer.toJson<int?>(utcOffsetMin),
    };
  }

  StoredFeeding copyWith(
          {String? id,
          String? type,
          String? startIso,
          String? endIso,
          int? leftMs,
          int? rightMs,
          Value<String?> endSide = const Value.absent(),
          int? amountMl,
          String? notes,
          Value<String?> updatedAt = const Value.absent(),
          Value<int?> utcOffsetMin = const Value.absent()}) =>
      StoredFeeding(
        id: id ?? this.id,
        type: type ?? this.type,
        startIso: startIso ?? this.startIso,
        endIso: endIso ?? this.endIso,
        leftMs: leftMs ?? this.leftMs,
        rightMs: rightMs ?? this.rightMs,
        endSide: endSide.present ? endSide.value : this.endSide,
        amountMl: amountMl ?? this.amountMl,
        notes: notes ?? this.notes,
        updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
        utcOffsetMin:
            utcOffsetMin.present ? utcOffsetMin.value : this.utcOffsetMin,
      );
  StoredFeeding copyWithCompanion(FeedingsCompanion data) {
    return StoredFeeding(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      startIso: data.startIso.present ? data.startIso.value : this.startIso,
      endIso: data.endIso.present ? data.endIso.value : this.endIso,
      leftMs: data.leftMs.present ? data.leftMs.value : this.leftMs,
      rightMs: data.rightMs.present ? data.rightMs.value : this.rightMs,
      endSide: data.endSide.present ? data.endSide.value : this.endSide,
      amountMl: data.amountMl.present ? data.amountMl.value : this.amountMl,
      notes: data.notes.present ? data.notes.value : this.notes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      utcOffsetMin: data.utcOffsetMin.present
          ? data.utcOffsetMin.value
          : this.utcOffsetMin,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredFeeding(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('startIso: $startIso, ')
          ..write('endIso: $endIso, ')
          ..write('leftMs: $leftMs, ')
          ..write('rightMs: $rightMs, ')
          ..write('endSide: $endSide, ')
          ..write('amountMl: $amountMl, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('utcOffsetMin: $utcOffsetMin')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, type, startIso, endIso, leftMs, rightMs,
      endSide, amountMl, notes, updatedAt, utcOffsetMin);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredFeeding &&
          other.id == this.id &&
          other.type == this.type &&
          other.startIso == this.startIso &&
          other.endIso == this.endIso &&
          other.leftMs == this.leftMs &&
          other.rightMs == this.rightMs &&
          other.endSide == this.endSide &&
          other.amountMl == this.amountMl &&
          other.notes == this.notes &&
          other.updatedAt == this.updatedAt &&
          other.utcOffsetMin == this.utcOffsetMin);
}

class FeedingsCompanion extends UpdateCompanion<StoredFeeding> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> startIso;
  final Value<String> endIso;
  final Value<int> leftMs;
  final Value<int> rightMs;
  final Value<String?> endSide;
  final Value<int> amountMl;
  final Value<String> notes;
  final Value<String?> updatedAt;
  final Value<int?> utcOffsetMin;
  final Value<int> rowid;
  const FeedingsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.startIso = const Value.absent(),
    this.endIso = const Value.absent(),
    this.leftMs = const Value.absent(),
    this.rightMs = const Value.absent(),
    this.endSide = const Value.absent(),
    this.amountMl = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.utcOffsetMin = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedingsCompanion.insert({
    required String id,
    required String type,
    required String startIso,
    required String endIso,
    this.leftMs = const Value.absent(),
    this.rightMs = const Value.absent(),
    this.endSide = const Value.absent(),
    this.amountMl = const Value.absent(),
    this.notes = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.utcOffsetMin = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        startIso = Value(startIso),
        endIso = Value(endIso);
  static Insertable<StoredFeeding> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? startIso,
    Expression<String>? endIso,
    Expression<int>? leftMs,
    Expression<int>? rightMs,
    Expression<String>? endSide,
    Expression<int>? amountMl,
    Expression<String>? notes,
    Expression<String>? updatedAt,
    Expression<int>? utcOffsetMin,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (startIso != null) 'start_iso': startIso,
      if (endIso != null) 'end_iso': endIso,
      if (leftMs != null) 'left_ms': leftMs,
      if (rightMs != null) 'right_ms': rightMs,
      if (endSide != null) 'end_side': endSide,
      if (amountMl != null) 'amount_ml': amountMl,
      if (notes != null) 'notes': notes,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (utcOffsetMin != null) 'utc_offset_min': utcOffsetMin,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String>? startIso,
      Value<String>? endIso,
      Value<int>? leftMs,
      Value<int>? rightMs,
      Value<String?>? endSide,
      Value<int>? amountMl,
      Value<String>? notes,
      Value<String?>? updatedAt,
      Value<int?>? utcOffsetMin,
      Value<int>? rowid}) {
    return FeedingsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      startIso: startIso ?? this.startIso,
      endIso: endIso ?? this.endIso,
      leftMs: leftMs ?? this.leftMs,
      rightMs: rightMs ?? this.rightMs,
      endSide: endSide ?? this.endSide,
      amountMl: amountMl ?? this.amountMl,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      utcOffsetMin: utcOffsetMin ?? this.utcOffsetMin,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (startIso.present) {
      map['start_iso'] = Variable<String>(startIso.value);
    }
    if (endIso.present) {
      map['end_iso'] = Variable<String>(endIso.value);
    }
    if (leftMs.present) {
      map['left_ms'] = Variable<int>(leftMs.value);
    }
    if (rightMs.present) {
      map['right_ms'] = Variable<int>(rightMs.value);
    }
    if (endSide.present) {
      map['end_side'] = Variable<String>(endSide.value);
    }
    if (amountMl.present) {
      map['amount_ml'] = Variable<int>(amountMl.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (utcOffsetMin.present) {
      map['utc_offset_min'] = Variable<int>(utcOffsetMin.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedingsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('startIso: $startIso, ')
          ..write('endIso: $endIso, ')
          ..write('leftMs: $leftMs, ')
          ..write('rightMs: $rightMs, ')
          ..write('endSide: $endSide, ')
          ..write('amountMl: $amountMl, ')
          ..write('notes: $notes, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('utcOffsetMin: $utcOffsetMin, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _feedingIdMeta =
      const VerificationMeta('feedingId');
  @override
  late final GeneratedColumn<String> feedingId = GeneratedColumn<String>(
      'feeding_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
      'op', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [feedingId, op];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('feeding_id')) {
      context.handle(_feedingIdMeta,
          feedingId.isAcceptableOrUnknown(data['feeding_id']!, _feedingIdMeta));
    } else if (isInserting) {
      context.missing(_feedingIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {feedingId};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      feedingId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feeding_id'])!,
      op: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}op'])!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final String feedingId;
  final String op;
  const OutboxEntry({required this.feedingId, required this.op});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['feeding_id'] = Variable<String>(feedingId);
    map['op'] = Variable<String>(op);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      feedingId: Value(feedingId),
      op: Value(op),
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      feedingId: serializer.fromJson<String>(json['feedingId']),
      op: serializer.fromJson<String>(json['op']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'feedingId': serializer.toJson<String>(feedingId),
      'op': serializer.toJson<String>(op),
    };
  }

  OutboxEntry copyWith({String? feedingId, String? op}) => OutboxEntry(
        feedingId: feedingId ?? this.feedingId,
        op: op ?? this.op,
      );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      feedingId: data.feedingId.present ? data.feedingId.value : this.feedingId,
      op: data.op.present ? data.op.value : this.op,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('feedingId: $feedingId, ')
          ..write('op: $op')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(feedingId, op);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.feedingId == this.feedingId &&
          other.op == this.op);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<String> feedingId;
  final Value<String> op;
  final Value<int> rowid;
  const OutboxEntriesCompanion({
    this.feedingId = const Value.absent(),
    this.op = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    required String feedingId,
    required String op,
    this.rowid = const Value.absent(),
  })  : feedingId = Value(feedingId),
        op = Value(op);
  static Insertable<OutboxEntry> custom({
    Expression<String>? feedingId,
    Expression<String>? op,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (feedingId != null) 'feeding_id': feedingId,
      if (op != null) 'op': op,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEntriesCompanion copyWith(
      {Value<String>? feedingId, Value<String>? op, Value<int>? rowid}) {
    return OutboxEntriesCompanion(
      feedingId: feedingId ?? this.feedingId,
      op: op ?? this.op,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (feedingId.present) {
      map['feeding_id'] = Variable<String>(feedingId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('feedingId: $feedingId, ')
          ..write('op: $op, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaEntriesTable extends MetaEntries
    with TableInfo<$MetaEntriesTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MetaEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $MetaEntriesTable createAlias(String alias) {
    return $MetaEntriesTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  const MetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetaEntriesCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory MetaEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaEntry copyWith({String? key, String? value}) => MetaEntry(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  MetaEntry copyWithCompanion(MetaEntriesCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaEntriesCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<MetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaEntriesCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return MetaEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FeedingsTable feedings = $FeedingsTable(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $MetaEntriesTable metaEntries = $MetaEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [feedings, outboxEntries, metaEntries];
}

typedef $$FeedingsTableCreateCompanionBuilder = FeedingsCompanion Function({
  required String id,
  required String type,
  required String startIso,
  required String endIso,
  Value<int> leftMs,
  Value<int> rightMs,
  Value<String?> endSide,
  Value<int> amountMl,
  Value<String> notes,
  Value<String?> updatedAt,
  Value<int?> utcOffsetMin,
  Value<int> rowid,
});
typedef $$FeedingsTableUpdateCompanionBuilder = FeedingsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> startIso,
  Value<String> endIso,
  Value<int> leftMs,
  Value<int> rightMs,
  Value<String?> endSide,
  Value<int> amountMl,
  Value<String> notes,
  Value<String?> updatedAt,
  Value<int?> utcOffsetMin,
  Value<int> rowid,
});

class $$FeedingsTableFilterComposer
    extends Composer<_$AppDatabase, $FeedingsTable> {
  $$FeedingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startIso => $composableBuilder(
      column: $table.startIso, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endIso => $composableBuilder(
      column: $table.endIso, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leftMs => $composableBuilder(
      column: $table.leftMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rightMs => $composableBuilder(
      column: $table.rightMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endSide => $composableBuilder(
      column: $table.endSide, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMl => $composableBuilder(
      column: $table.amountMl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get utcOffsetMin => $composableBuilder(
      column: $table.utcOffsetMin, builder: (column) => ColumnFilters(column));
}

class $$FeedingsTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedingsTable> {
  $$FeedingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startIso => $composableBuilder(
      column: $table.startIso, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endIso => $composableBuilder(
      column: $table.endIso, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leftMs => $composableBuilder(
      column: $table.leftMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rightMs => $composableBuilder(
      column: $table.rightMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endSide => $composableBuilder(
      column: $table.endSide, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMl => $composableBuilder(
      column: $table.amountMl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get utcOffsetMin => $composableBuilder(
      column: $table.utcOffsetMin,
      builder: (column) => ColumnOrderings(column));
}

class $$FeedingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedingsTable> {
  $$FeedingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get startIso =>
      $composableBuilder(column: $table.startIso, builder: (column) => column);

  GeneratedColumn<String> get endIso =>
      $composableBuilder(column: $table.endIso, builder: (column) => column);

  GeneratedColumn<int> get leftMs =>
      $composableBuilder(column: $table.leftMs, builder: (column) => column);

  GeneratedColumn<int> get rightMs =>
      $composableBuilder(column: $table.rightMs, builder: (column) => column);

  GeneratedColumn<String> get endSide =>
      $composableBuilder(column: $table.endSide, builder: (column) => column);

  GeneratedColumn<int> get amountMl =>
      $composableBuilder(column: $table.amountMl, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get utcOffsetMin => $composableBuilder(
      column: $table.utcOffsetMin, builder: (column) => column);
}

class $$FeedingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FeedingsTable,
    StoredFeeding,
    $$FeedingsTableFilterComposer,
    $$FeedingsTableOrderingComposer,
    $$FeedingsTableAnnotationComposer,
    $$FeedingsTableCreateCompanionBuilder,
    $$FeedingsTableUpdateCompanionBuilder,
    (
      StoredFeeding,
      BaseReferences<_$AppDatabase, $FeedingsTable, StoredFeeding>
    ),
    StoredFeeding,
    PrefetchHooks Function()> {
  $$FeedingsTableTableManager(_$AppDatabase db, $FeedingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> startIso = const Value.absent(),
            Value<String> endIso = const Value.absent(),
            Value<int> leftMs = const Value.absent(),
            Value<int> rightMs = const Value.absent(),
            Value<String?> endSide = const Value.absent(),
            Value<int> amountMl = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String?> updatedAt = const Value.absent(),
            Value<int?> utcOffsetMin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedingsCompanion(
            id: id,
            type: type,
            startIso: startIso,
            endIso: endIso,
            leftMs: leftMs,
            rightMs: rightMs,
            endSide: endSide,
            amountMl: amountMl,
            notes: notes,
            updatedAt: updatedAt,
            utcOffsetMin: utcOffsetMin,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required String startIso,
            required String endIso,
            Value<int> leftMs = const Value.absent(),
            Value<int> rightMs = const Value.absent(),
            Value<String?> endSide = const Value.absent(),
            Value<int> amountMl = const Value.absent(),
            Value<String> notes = const Value.absent(),
            Value<String?> updatedAt = const Value.absent(),
            Value<int?> utcOffsetMin = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FeedingsCompanion.insert(
            id: id,
            type: type,
            startIso: startIso,
            endIso: endIso,
            leftMs: leftMs,
            rightMs: rightMs,
            endSide: endSide,
            amountMl: amountMl,
            notes: notes,
            updatedAt: updatedAt,
            utcOffsetMin: utcOffsetMin,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$FeedingsTable, StoredFeeding>(table),
                    BaseReferences<_$AppDatabase, $FeedingsTable,
                        StoredFeeding>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FeedingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FeedingsTable,
    StoredFeeding,
    $$FeedingsTableFilterComposer,
    $$FeedingsTableOrderingComposer,
    $$FeedingsTableAnnotationComposer,
    $$FeedingsTableCreateCompanionBuilder,
    $$FeedingsTableUpdateCompanionBuilder,
    (
      StoredFeeding,
      BaseReferences<_$AppDatabase, $FeedingsTable, StoredFeeding>
    ),
    StoredFeeding,
    PrefetchHooks Function()>;
typedef $$OutboxEntriesTableCreateCompanionBuilder = OutboxEntriesCompanion
    Function({
  required String feedingId,
  required String op,
  Value<int> rowid,
});
typedef $$OutboxEntriesTableUpdateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<String> feedingId,
  Value<String> op,
  Value<int> rowid,
});

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get feedingId => $composableBuilder(
      column: $table.feedingId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get op => $composableBuilder(
      column: $table.op, builder: (column) => ColumnFilters(column));
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get feedingId => $composableBuilder(
      column: $table.feedingId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get op => $composableBuilder(
      column: $table.op, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get feedingId =>
      $composableBuilder(column: $table.feedingId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()> {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> feedingId = const Value.absent(),
            Value<String> op = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEntriesCompanion(
            feedingId: feedingId,
            op: op,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String feedingId,
            required String op,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxEntriesCompanion.insert(
            feedingId: feedingId,
            op: op,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                    BaseReferences<_$AppDatabase, $OutboxEntriesTable,
                        OutboxEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()>;
typedef $$MetaEntriesTableCreateCompanionBuilder = MetaEntriesCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaEntriesTableUpdateCompanionBuilder = MetaEntriesCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$MetaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$MetaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$AppDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()> {
  $$MetaEntriesTableTableManager(_$AppDatabase db, $MetaEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MetaEntriesTable, MetaEntry>(table),
                    BaseReferences<_$AppDatabase, $MetaEntriesTable, MetaEntry>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MetaEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$AppDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FeedingsTableTableManager get feedings =>
      $$FeedingsTableTableManager(_db, _db.feedings);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$MetaEntriesTableTableManager get metaEntries =>
      $$MetaEntriesTableTableManager(_db, _db.metaEntries);
}
