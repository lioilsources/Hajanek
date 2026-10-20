import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../features/catalog/catalog_models.dart';

part 'database.g.dart';

class Favourites extends Table {
  TextColumn get taleId => text()();
  DateTimeColumn get addedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {taleId};
}

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taleId => text()();
  TextColumn get voice => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
}

class UserPresets extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get layersJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Small key/value store for settings, last volumes and timer choice.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Favourites, History, UserPresets, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'hajanek'));

  @override
  int get schemaVersion => 1;

  // Favourites
  Stream<Set<String>> watchFavourites() =>
      select(favourites).watch().map((rows) => {for (final r in rows) r.taleId});

  Future<void> setFavourite(String taleId, bool on) async {
    if (on) {
      await into(favourites).insertOnConflictUpdate(
          FavouritesCompanion.insert(taleId: taleId, addedAt: DateTime.now()));
    } else {
      await (delete(favourites)..where((f) => f.taleId.equals(taleId))).go();
    }
  }

  // History
  Future<int> startHistory(String taleId, String voice, DateTime at) => into(history)
      .insert(HistoryCompanion.insert(taleId: taleId, voice: voice, startedAt: at));

  Future<void> finishHistory(int id, DateTime at) =>
      (update(history)..where((h) => h.id.equals(id)))
          .write(HistoryCompanion(finishedAt: Value(at)));

  // User presets
  Stream<List<MixPreset>> watchUserPresets() =>
      (select(userPresets)..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
          .watch()
          .map((rows) => [
                for (final r in rows)
                  MixPreset(
                    id: r.id,
                    title: r.title,
                    user: true,
                    layers: [
                      for (final l in jsonDecode(r.layersJson) as List)
                        MixLayer.fromJson(l as Map<String, dynamic>),
                    ],
                  ),
              ]);

  Future<void> saveUserPreset(MixPreset p) => into(userPresets).insertOnConflictUpdate(
        UserPresetsCompanion.insert(
          id: p.id,
          title: p.title,
          layersJson: jsonEncode([for (final l in p.layers) l.toJson()]),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> deleteUserPreset(String id) =>
      (delete(userPresets)..where((p) => p.id.equals(id))).go();

  // Key/value
  Future<Map<String, String>> readAllValues() async =>
      {for (final r in await select(keyValues).get()) r.key: r.value};

  Future<void> writeValue(String key, String value) => into(keyValues)
      .insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));
}
