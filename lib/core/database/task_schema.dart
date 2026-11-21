import 'package:sqflite/sqflite.dart';

abstract final class TaskSchema {
  static Future<void> create(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL CHECK(length(trim(title)) > 0),
        description TEXT,
        priority TEXT NOT NULL CHECK(priority IN ('low', 'medium', 'high')),
        is_completed INTEGER NOT NULL DEFAULT 0 CHECK(is_completed IN (0, 1)),
        created_at INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE activity_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('created', 'priorityChanged', 'completed', 'reopened')),
        old_value TEXT,
        new_value TEXT,
        occurred_at INTEGER NOT NULL,
        FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    await database.execute(
      'CREATE INDEX activity_task_time ON activity_events(task_id, occurred_at, id)',
    );
  }

  static Future<void> migrate(
    DatabaseExecutor database,
    int oldVersion,
    int newVersion,
  ) async {
    throw UnsupportedError(
      'No migration registered from schema $oldVersion to $newVersion.',
    );
  }
}
