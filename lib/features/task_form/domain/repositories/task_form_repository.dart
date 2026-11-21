import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';

abstract interface class TaskFormRepository {
  Future<int> createTask(TaskFormData data);
  Future<void> updateTask(TaskFormData data);
}
