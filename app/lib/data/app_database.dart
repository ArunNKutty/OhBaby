import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('StoredFeeding')
class Feedings extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get startIso => text()();
  TextColumn get endIso => text()();
  IntColumn get leftMs => integer().withDefault(const Constant(0))();
  IntColumn get rightMs => integer().withDefault(const Constant(0))();
  TextColumn get endSide => text().nullable()();
  IntColumn get amountMl => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get updatedAt => text().nullable()();
  IntColumn get utcOffsetMin => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class OutboxEntries extends Table {
  TextColumn get feedingId => text()();
  TextColumn get op => text()();

  @override
  Set<Column> get primaryKey => {feedingId};
}

class MetaEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Feedings, OutboxEntries, MetaEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                name: 'oh_baby_baby',
                web: DriftWebOptions(
                  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                  driftWorker: Uri.parse('drift_worker.js'),
                ),
              ),
        );

  @override
  int get schemaVersion => 1;
}
