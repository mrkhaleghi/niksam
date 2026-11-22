import 'package:niksam/features/task_list/domain/entities/task.dart';

/// Criteria understood by task repositories, independent of widgets and SQL.
class TaskListQuery {
  const TaskListQuery({this.title = '', this.priority, this.completed});

  final String title;
  final TaskPriority? priority;
  final bool? completed;
}
