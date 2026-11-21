import 'package:sqflite/sqflite.dart';

import 'package:niksam/core/database/local_write_coordinator.dart';

class TaskListLocalDataSource {
  const TaskListLocalDataSource(
    this._database,
    this._writes, {
    this.failWrites = false,
  });

  final Database _database;
  final LocalWriteCoordinator _writes;
  final bool failWrites;

  Future<List<Map<String, Object?>>> getTasks() async {
    await _writes.settled;
    return _database.query('tasks', orderBy: 'created_at DESC, id DESC');
  }

  Future<List<Map<String, Object?>>> getActivity(int taskId) async {
    await _writes.settled;
    return _database.query(
      'activity_events',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'occurred_at ASC, id ASC',
    );
  }

  Future<void> toggleCompleted(int taskId) => _writes.run(
    () => _database.transaction((transaction) async {
      final rows = await transaction.query(
        'tasks',
        columns: ['is_completed'],
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Task no longer exists.');
      // Read the committed value rather than the checkbox's stale value.
      final wasCompleted = rows.single['is_completed'] == 1;
      await transaction.update(
        'tasks',
        {'is_completed': wasCompleted ? 0 : 1},
        where: 'id = ?',
        whereArgs: [taskId],
      );
      _maybeFail();
      await transaction.insert('activity_events', {
        'task_id': taskId,
        'type': wasCompleted ? 'reopened' : 'completed',
        'occurred_at': DateTime.now().toUtc().microsecondsSinceEpoch,
      });
    }),
  );

  Future<void> deleteTask(int taskId) => _writes.run(() async {
    final rows = await _database.query(
      'tasks',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    await _database.transaction((transaction) async {
      // Foreign keys cascade the associated history in this same transaction.
      await transaction.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
      _maybeFail();
    });
  });

  void _maybeFail() {
    if (failWrites) {
      throw StateError('Write failure injected with FAIL_WRITES=true.');
    }
  }
}
