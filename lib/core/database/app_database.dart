import 'package:sqflite/sqflite.dart';

import 'package:niksam/core/database/task_schema.dart';

abstract final class AppDatabase {
  static const schemaVersion = 1;

  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ?? '${await selectedFactory.getDatabasesPath()}/tasks.db';
    return selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (database) async {
          await database.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (database, version) => TaskSchema.create(database),
        onUpgrade: (database, oldVersion, newVersion) =>
            TaskSchema.migrate(database, oldVersion, newVersion),
      ),
    );
  }
}
