import 'package:sqflite/sqflite.dart';

import 'package:niksam/core/database/local_write_coordinator.dart';

abstract interface class TaskFormLocalDataSource {
  Future<int> createTask(Map<String, Object?> values);
  Future<void> updateTask({
    required int taskId,
    required Map<String, Object?> values,
  });
}

class SqfliteTaskFormLocalDataSource implements TaskFormLocalDataSource {
  const SqfliteTaskFormLocalDataSource(
    this._database,
    this._writes, {
    this.failWrites = false,
  });

  final Database _database;
  final LocalWriteCoordinator _writes;
  final bool failWrites;

  @override
  Future<int> createTask(Map<String, Object?> values) => _writes.run(() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    return _database.transaction((transaction) async {
      final taskId = await transaction.insert('tasks', {
        ...values,
        'is_completed': 0,
        'created_at': now,
      });
      _maybeFail();
      await transaction.insert('activity_events', {
        'task_id': taskId,
        'type': 'created',
        'occurred_at': now,
      });
      return taskId;
    });
  });

  @override
  Future<void> updateTask({
    required int taskId,
    required Map<String, Object?> values,
  }) => _writes.run(() async {
    final rows = await _database.query(
      'tasks', where: 'id = ?', whereArgs: [taskId], limit: 1,
    );
    if (rows.isEmpty) throw StateError('Task no longer exists.');
    final existing = rows.single;
    // Check before opening a transaction, including when FAIL_WRITES is set.
    if (values.entries.every((entry) => existing[entry.key] == entry.value)) {
      return;
    }
    final oldPriority = existing['priority'];
    await _database.transaction((transaction) async {
      await transaction.update('tasks', values,
          where: 'id = ?', whereArgs: [taskId]);
      _maybeFail();
      if (oldPriority != values['priority']) {
        await transaction.insert('activity_events', {
          'task_id': taskId,
          'type': 'priorityChanged',
          'old_value': oldPriority,
          'new_value': values['priority'],
          'occurred_at': DateTime.now().toUtc().microsecondsSinceEpoch,
        });
      }
    });
  });

  void _maybeFail() {
    // Fail between the task and history writes to exercise rollback.
    if (failWrites) throw StateError('Write failure injected with FAIL_WRITES=true.');
  }
}
