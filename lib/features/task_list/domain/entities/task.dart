enum TaskPriority { low, medium, high }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
}
