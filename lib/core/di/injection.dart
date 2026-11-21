import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';

import 'package:niksam/core/database/app_database.dart';
import 'package:niksam/core/database/local_write_coordinator.dart';
import 'package:niksam/features/task_form/data/repositories/task_form_repository_impl.dart';
import 'package:niksam/features/task_form/data/services/local/task_form_local_data_source.dart';
import 'package:niksam/features/task_form/domain/repositories/task_form_repository.dart';
import 'package:niksam/features/task_list/data/repositories/task_list_repository_impl.dart';
import 'package:niksam/features/task_list/data/services/local/task_list_local_data_source.dart';
import 'package:niksam/features/task_list/domain/repositories/task_list_repository.dart';

final GetIt getIt = GetIt.instance;
Future<void>? _pendingConfiguration;

Future<void> configureDependencies() {
  if (getIt.isRegistered<TaskFormRepository>()) return Future<void>.value();
  return _pendingConfiguration ??= _openDependencies().whenComplete(() {
    _pendingConfiguration = null;
  });
}

Future<void> _openDependencies() async {
  final database = await AppDatabase.open();
  final writes = LocalWriteCoordinator();
  const failWrites = bool.fromEnvironment('FAIL_WRITES');
  getIt.registerSingleton<Database>(
    database,
    dispose: (database) async {
      await writes.settled;
      await database.close();
    },
  );
  getIt.registerSingleton<TaskListRepository>(
    TaskListRepositoryImpl(
      TaskListLocalDataSource(database, writes, failWrites: failWrites),
    ),
  );
  getIt.registerSingleton<TaskFormRepository>(
    TaskFormRepositoryImpl(
      SqfliteTaskFormLocalDataSource(database, writes, failWrites: failWrites),
    ),
  );
}
