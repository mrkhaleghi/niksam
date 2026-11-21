import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';

abstract interface class TaskListRepository {
  Future<List<Task>> getTasks();
  Future<List<TaskActivity>> getActivity(int taskId);
  Future<void> toggleCompleted(int taskId);
  Future<void> deleteTask(int taskId);
}
