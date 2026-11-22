import 'package:niksam/features/task_list/domain/entities/task.dart';

class TaskListResult {
  TaskListResult({required List<Task> tasks, required this.totalCount})
    : tasks = List.unmodifiable(tasks);

  final List<Task> tasks;

  /// Unfiltered count for the list's badge and empty-state distinction.
  final int totalCount;
}
