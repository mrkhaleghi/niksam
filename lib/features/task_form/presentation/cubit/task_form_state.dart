import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';

enum TaskFormStatus { initial, saving, success, failure }

class TaskFormState {
  const TaskFormState({required this.data, this.status = TaskFormStatus.initial});

  final TaskFormData data;
  final TaskFormStatus status;
}
