enum TaskFormPriority { low, medium, high }

class TaskFormData {
  const TaskFormData({
    this.taskId,
    required this.title,
    required this.description,
    required this.priority,
  });

  final int? taskId;
  final String title;
  final String? description;
  final TaskFormPriority priority;
}
