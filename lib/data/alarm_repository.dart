import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'alarm.dart';

/// Owns the SQLite table that is the single source of truth for alarms.
///
/// Deliberately plain `sqflite` (no code generation) so this compiles with
/// nothing more than `flutter pub get` — no build_runner step required to
/// get a runnable app. If the schema grows a lot, swapping this for `drift`
/// later is a contained change (repository interface stays the same).
class AlarmRepository {
  static const _dbName = 'rise_protocol.db';
  static const _table = 'alarms';

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            label TEXT NOT NULL DEFAULT '',
            enabled INTEGER NOT NULL DEFAULT 1,
            repeat_days TEXT NOT NULL DEFAULT '[]',
            mission_type TEXT NOT NULL DEFAULT 'math',
            mission_difficulty INTEGER NOT NULL DEFAULT 1,
            sound_asset TEXT NOT NULL DEFAULT 'default_alarm',
            snooze_minutes INTEGER NOT NULL DEFAULT 5,
            max_snoozes INTEGER NOT NULL DEFAULT 3
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Alarm>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'hour, minute');
    return rows.map(Alarm.fromMap).toList();
  }

  Future<Alarm> insert(Alarm alarm) async {
    final db = await _database;
    final map = alarm.toMap()..remove('id');
    final id = await db.insert(_table, map);
    return alarm.copyWith(id: id);
  }

  Future<void> update(Alarm alarm) async {
    assert(alarm.id != null, 'Cannot update an alarm without an id');
    final db = await _database;
    await db.update(_table, alarm.toMap(), where: 'id = ?', whereArgs: [alarm.id]);
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  return AlarmRepository();
});

/// The list of all alarms, kept in sync with the database. UI reads this;
/// mutations go through [AlarmListController].
final alarmListProvider =
    AsyncNotifierProvider<AlarmListController, List<Alarm>>(AlarmListController.new);

class AlarmListController extends AsyncNotifier<List<Alarm>> {
  @override
  Future<List<Alarm>> build() {
    return ref.read(alarmRepositoryProvider).getAll();
  }

  Future<void> _reload() async {
    state = AsyncValue.data(await ref.read(alarmRepositoryProvider).getAll());
  }

  Future<Alarm> add(Alarm alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    final saved = await repo.insert(alarm);
    await _reload();
    return saved;
  }

  Future<void> save(Alarm alarm) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.update(alarm);
    await _reload();
  }

  Future<void> remove(int id) async {
    final repo = ref.read(alarmRepositoryProvider);
    await repo.delete(id);
    await _reload();
  }

  Future<void> setEnabled(Alarm alarm, bool enabled) async {
    await save(alarm.copyWith(enabled: enabled));
  }
}
