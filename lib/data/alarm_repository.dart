import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'alarm.dart';

/// The single source of truth for alarms. [SqfliteAlarmRepository] is the
/// real one; [InMemoryAlarmRepository] backs the web UI preview (sqflite has
/// no web support and the preview doesn't need persistence).
abstract interface class AlarmRepository {
  Future<List<Alarm>> getAll();
  Future<Alarm> insert(Alarm alarm);
  Future<void> update(Alarm alarm);
  Future<void> delete(int id);
}

/// Plain `sqflite` (no code generation) so this compiles with nothing more
/// than `flutter pub get`. If the schema grows a lot, swapping this for
/// `drift` later is a contained change — the interface stays the same.
class SqfliteAlarmRepository implements AlarmRepository {
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

  @override
  Future<List<Alarm>> getAll() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'hour, minute');
    return rows.map(Alarm.fromMap).toList();
  }

  @override
  Future<Alarm> insert(Alarm alarm) async {
    final db = await _database;
    final map = alarm.toMap()..remove('id');
    final id = await db.insert(_table, map);
    return alarm.copyWith(id: id);
  }

  @override
  Future<void> update(Alarm alarm) async {
    assert(alarm.id != null, 'Cannot update an alarm without an id');
    final db = await _database;
    await db.update(_table, alarm.toMap(), where: 'id = ?', whereArgs: [alarm.id]);
  }

  @override
  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}

/// Ephemeral store for the web UI preview. Seeded with a few demo alarms so
/// the list isn't empty on first load; changes last only for the session.
class InMemoryAlarmRepository implements AlarmRepository {
  InMemoryAlarmRepository(this._alarms) {
    for (final a in _alarms) {
      if (a.id != null && a.id! >= _nextId) _nextId = a.id! + 1;
    }
  }

  factory InMemoryAlarmRepository.demo() => InMemoryAlarmRepository([
        const Alarm(
          id: 1,
          hour: 6,
          minute: 40,
          label: 'Gym',
          repeatDays: {1, 2, 3, 4, 5},
        ),
        const Alarm(id: 2, hour: 8, minute: 0, repeatDays: {6, 7}),
        const Alarm(
          id: 3,
          hour: 13,
          minute: 30,
          label: 'Power nap',
          enabled: false,
          missionType: MissionType.none,
        ),
      ]);

  final List<Alarm> _alarms;
  int _nextId = 1;

  @override
  Future<List<Alarm>> getAll() async {
    final copy = [..._alarms]
      ..sort((a, b) =>
          (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return copy;
  }

  @override
  Future<Alarm> insert(Alarm alarm) async {
    final saved = alarm.copyWith(id: _nextId++);
    _alarms.add(saved);
    return saved;
  }

  @override
  Future<void> update(Alarm alarm) async {
    final i = _alarms.indexWhere((a) => a.id == alarm.id);
    if (i != -1) _alarms[i] = alarm;
  }

  @override
  Future<void> delete(int id) async {
    _alarms.removeWhere((a) => a.id == id);
  }
}

final alarmRepositoryProvider = Provider<AlarmRepository>(
  (ref) => kIsWeb ? InMemoryAlarmRepository.demo() : SqfliteAlarmRepository(),
);

/// The list of all alarms, kept in sync with the store. UI reads this;
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
