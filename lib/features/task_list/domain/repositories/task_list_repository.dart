import 'package:niksam/features/task_list/domain/entities/task_activity.dart';
import 'package:niksam/features/task_list/domain/entities/task_list_query.dart';
import 'package:niksam/features/task_list/domain/entities/task_list_result.dart';

abstract interface class TaskListRepository {
  Future<TaskListResult> getTasks({
    TaskListQuery query = const TaskListQuery(),
  });
  Future<List<TaskActivity>> getActivity(int taskId);
  Future<void> toggleCompleted(int taskId);
  Future<void> deleteTask(int taskId);
}
