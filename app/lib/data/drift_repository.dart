import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/entry.dart';
import 'app_database.dart';
import 'feeding_repository.dart';

class DriftFeedingRepository implements FeedingRepository {
  DriftFeedingRepository(this.db);

  final AppDatabase db;

  @override
  Future<RepoSnapshot> load() async {
    final rows = await db.select(db.entries).get();
    final metas = await db.select(db.metaEntries).get();
    final queued = await db.select(db.outboxEntries).get();
    final photo = await (db.select(db.localBlobs)..where((t) => t.key.equals('baby_photo'))).getSingleOrNull();
    final meta = {for (final m in metas) m.key: m.value};
    final babyId = meta['baby_id'] ?? const Uuid().v4();
    if (!meta.containsKey('baby_id')) {
      await setMeta('baby_id', babyId);
      meta['baby_id'] = babyId;
    }
    return RepoSnapshot(
      entries: rows.map(_fromRow).whereType<Entry>().toList(),
      babyName: meta['baby_name'] ?? 'My baby',
      babyId: babyId,
      meta: meta,
      outbox: {for (final q in queued) q.entryId: q.op},
      babyPhoto: photo?.data,
    );
  }

  Entry? _fromRow(StoredEntry row) {
    final type = EntryType.values.asNameMap()[row.type];
    if (type == null) return null;
    return Entry(
      id: row.id,
      type: type,
      start: DateTime.parse(row.startIso),
      end: DateTime.parse(row.endIso),
      leftDuration: Duration(milliseconds: row.leftMs),
      rightDuration: Duration(milliseconds: row.rightMs),
      endSide: row.endSide == null ? null : BreastSide.values.asNameMap()[row.endSide!],
      amountMl: row.amountMl,
      leftMl: row.leftMl,
      rightMl: row.rightMl,
      diaper: row.diaper == null ? null : DiaperKind.values.asNameMap()[row.diaper!],
      rash: row.rash,
      title: row.title,
      value: row.value,
      unit: row.unit,
      notes: row.notes,
      updatedAt: row.updatedAt == null ? null : DateTime.parse(row.updatedAt!),
      utcOffsetMin: row.utcOffsetMin,
    );
  }

  EntriesCompanion _companion(Entry e) => EntriesCompanion.insert(
        id: e.id,
        type: e.type.name,
        startIso: e.start.toIso8601String(),
        endIso: e.end.toIso8601String(),
        leftMs: Value(e.leftDuration.inMilliseconds),
        rightMs: Value(e.rightDuration.inMilliseconds),
        endSide: Value(e.endSide?.name),
        amountMl: Value(e.amountMl),
        leftMl: Value(e.leftMl),
        rightMl: Value(e.rightMl),
        diaper: Value(e.diaper?.name),
        rash: Value(e.rash),
        title: Value(e.title),
        value: Value(e.value),
        unit: Value(e.unit),
        notes: Value(e.notes),
        updatedAt: Value(e.updatedAt?.toUtc().toIso8601String()),
        utcOffsetMin: Value(e.utcOffsetMin),
      );

  @override
  Future<void> upsertEntry(Entry entry) => db.into(db.entries).insertOnConflictUpdate(_companion(entry));

  @override
  Future<void> deleteEntry(String id) => (db.delete(db.entries)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> setMeta(String key, String value) =>
      db.into(db.metaEntries).insertOnConflictUpdate(MetaEntriesCompanion.insert(key: key, value: value));

  @override
  Future<void> removeMeta(String key) => (db.delete(db.metaEntries)..where((t) => t.key.equals(key))).go();

  @override
  Future<void> setOutbox(String entryId, String op) =>
      db.into(db.outboxEntries).insertOnConflictUpdate(OutboxEntriesCompanion.insert(entryId: entryId, op: op));

  @override
  Future<void> removeOutbox(String entryId) =>
      (db.delete(db.outboxEntries)..where((t) => t.entryId.equals(entryId))).go();

  @override
  Future<void> setBlob(String key, Uint8List? data) async {
    if (data == null) {
      await (db.delete(db.localBlobs)..where((t) => t.key.equals(key))).go();
    } else {
      await db.into(db.localBlobs).insertOnConflictUpdate(LocalBlobsCompanion.insert(key: key, data: data));
    }
  }

  @override
  Future<void> wipe() async {
    await db.transaction(() async {
      await db.delete(db.entries).go();
      await db.delete(db.outboxEntries).go();
      await db.delete(db.metaEntries).go();
      await db.delete(db.localBlobs).go();
    });
  }
}
