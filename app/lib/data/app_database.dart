import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('StoredEntry')
class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get startIso => text()();
  TextColumn get endIso => text()();
  IntColumn get leftMs => integer().withDefault(const Constant(0))();
  IntColumn get rightMs => integer().withDefault(const Constant(0))();
  TextColumn get endSide => text().nullable()();
  IntColumn get amountMl => integer().withDefault(const Constant(0))();
  IntColumn get leftMl => integer().withDefault(const Constant(0))();
  IntColumn get rightMl => integer().withDefault(const Constant(0))();
  TextColumn get diaper => text().nullable()();
  BoolColumn get rash => boolean().withDefault(const Constant(false))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get value => text().withDefault(const Constant(''))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get updatedAt => text().nullable()();
  IntColumn get utcOffsetMin => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxEntries extends Table {
  TextColumn get entryId => text()();
  TextColumn get op => text()();

  @override
  Set<Column> get primaryKey => {entryId};
}

class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Device-only files, such as the baby's photo. Never synced.
class LocalBlobs extends Table {
  TextColumn get key => text()();
  BlobColumn get data => blob()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Entries, OutboxEntries, MetaEntries, LocalBlobs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                // A new name starts every device with an empty log for this
                // version of the app instead of upgrading the old one.
                name: 'oh_baby_baby_v4',
                web: DriftWebOptions(
                  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                  driftWorker: Uri.parse('drift_worker.js'),
                ),
              ),
        );

  @override
  int get schemaVersion => 1;
}
