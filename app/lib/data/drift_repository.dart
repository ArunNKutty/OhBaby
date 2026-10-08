import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../models/feeding.dart';
import 'app_database.dart';
import 'feeding_repository.dart';

class DriftFeedingRepository implements FeedingRepository {
  DriftFeedingRepository(this.db);

  final AppDatabase db;

  @override
  Future<RepoSnapshot> load() async {
    final rows = await db.select(db.feedings).get();
    final metas = await db.select(db.metaEntries).get();
    final queued = await db.select(db.outboxEntries).get();
    final meta = {for (final m in metas) m.key: m.value};
    final babyId = meta['baby_id'] ?? const Uuid().v4();
    if (!meta.containsKey('baby_id')) {
      await setMeta('baby_id', babyId);
      meta['baby_id'] = babyId;
    }
    return RepoSnapshot(
      feedings: rows.map(_fromRow).toList(),
      babyName: meta['baby_name'] ?? 'My baby',
      babyId: babyId,
      meta: meta,
      outbox: {for (final q in queued) q.feedingId: q.op},
    );
  }

  Feeding _fromRow(StoredFeeding row) => Feeding(
        id: row.id,
        type: FeedingType.values.byName(row.type),
        start: DateTime.parse(row.startIso),
        end: DateTime.parse(row.endIso),
        leftDuration: Duration(milliseconds: row.leftMs),
        rightDuration: Duration(milliseconds: row.rightMs),
        endSide: row.endSide == null ? null : BreastSide.values.byName(row.endSide!),
        amountMl: row.amountMl,
        notes: row.notes,
        updatedAt: row.updatedAt == null ? null : DateTime.parse(row.updatedAt!),
        utcOffsetMin: row.utcOffsetMin,
      );

  FeedingsCompanion _companion(Feeding feeding) => FeedingsCompanion.insert(
        id: feeding.id,
        type: feeding.type.name,
        startIso: feeding.start.toIso8601String(),
        endIso: feeding.end.toIso8601String(),
        leftMs: Value(feeding.leftDuration.inMilliseconds),
        rightMs: Value(feeding.rightDuration.inMilliseconds),
        endSide: Value(feeding.endSide?.name),
        amountMl: Value(feeding.amountMl),
        notes: Value(feeding.notes),
        updatedAt: Value(feeding.updatedAt?.toUtc().toIso8601String()),
        utcOffsetMin: Value(feeding.utcOffsetMin),
      );

  @override
  Future<void> upsertFeeding(Feeding feeding) {
    return db.into(db.feedings).insertOnConflictUpdate(_companion(feeding));
  }

  @override
  Future<void> deleteFeeding(String id) {
    return (db.delete(db.feedings)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> setMeta(String key, String value) {
    return db.into(db.metaEntries).insertOnConflictUpdate(
          MetaEntriesCompanion.insert(key: key, value: value),
        );
  }

  @override
  Future<void> removeMeta(String key) {
    return (db.delete(db.metaEntries)..where((t) => t.key.equals(key))).go();
  }

  @override
  Future<void> setOutbox(String feedingId, String op) {
    return db.into(db.outboxEntries).insertOnConflictUpdate(
          OutboxEntriesCompanion.insert(feedingId: feedingId, op: op),
        );
  }

  @override
  Future<void> removeOutbox(String feedingId) {
    return (db.delete(db.outboxEntries)..where((t) => t.feedingId.equals(feedingId))).go();
  }

  @override
  Future<void> replaceAll(List<Feeding> feedings) async {
    await db.transaction(() async {
      await db.delete(db.feedings).go();
      await db.batch((b) {
        b.insertAll(db.feedings, feedings.map(_companion));
      });
    });
  }

  @override
  Future<void> wipe() async {
    await db.transaction(() async {
      await db.delete(db.feedings).go();
      await db.delete(db.outboxEntries).go();
      await db.delete(db.metaEntries).go();
    });
  }
}
