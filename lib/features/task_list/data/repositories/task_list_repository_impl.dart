import 'package:niksam/features/task_list/data/services/local/task_list_local_data_source.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';
import 'package:niksam/features/task_list/domain/entities/task_list_query.dart';
import 'package:niksam/features/task_list/domain/entities/task_list_result.dart';
import 'package:niksam/features/task_list/domain/repositories/task_list_repository.dart';

class TaskListRepositoryImpl implements TaskListRepository {
  const TaskListRepositoryImpl(this._localDataSource);

  final TaskListLocalDataSource _localDataSource;

  @override
  Future<TaskListResult> getTasks({
    TaskListQuery query = const TaskListQuery(),
  }) async {
    final result = await _localDataSource.getTasks(query);
    return TaskListResult(
      tasks: result.tasks.map(_taskFromRow).toList(growable: false),
      totalCount: result.totalCount,
    );
  }

  @override
  Future<List<TaskActivity>> getActivity(int taskId) async => List.unmodifiable(
    (await _localDataSource.getActivity(taskId)).map(_activityFromRow),
  );

  @override
  Future<void> toggleCompleted(int taskId) =>
      _localDataSource.toggleCompleted(taskId);

  @override
  Future<void> deleteTask(int taskId) => _localDataSource.deleteTask(taskId);
}

Task _taskFromRow(Map<String, Object?> row) => Task(
  id: row['id'] as int,
  title: row['title'] as String,
  description: row['description'] as String?,
  priority: TaskPriority.values.byName(row['priority'] as String),
  isCompleted: row['is_completed'] == 1,
  createdAt: DateTime.fromMicrosecondsSinceEpoch(
    row['created_at'] as int,
    isUtc: true,
  ),
);

TaskActivity _activityFromRow(Map<String, Object?> row) => TaskActivity(
  id: row['id'] as int,
  taskId: row['task_id'] as int,
  type: TaskActivityType.values.byName(row['type'] as String),
  oldValue: row['old_value'] as String?,
  newValue: row['new_value'] as String?,
  occurredAt: DateTime.fromMicrosecondsSinceEpoch(
    row['occurred_at'] as int,
    isUtc: true,
  ),
);
