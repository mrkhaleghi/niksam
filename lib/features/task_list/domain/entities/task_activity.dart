enum TaskActivityType { created, priorityChanged, completed, reopened }

class TaskActivity {
  const TaskActivity({
    required this.id,
    required this.taskId,
    required this.type,
    required this.occurredAt,
    this.oldValue,
    this.newValue,
  });

  final int id;
  final int taskId;
  final TaskActivityType type;
  final DateTime occurredAt;
  final String? oldValue;
  final String? newValue;
}
