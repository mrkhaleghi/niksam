import 'package:niksam/features/task_form/data/services/local/task_form_local_data_source.dart';
import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_form/domain/repositories/task_form_repository.dart';

class TaskFormRepositoryImpl implements TaskFormRepository {
  const TaskFormRepositoryImpl(this._localDataSource);

  final TaskFormLocalDataSource _localDataSource;

  @override
  Future<int> createTask(TaskFormData data) =>
      _localDataSource.createTask(_values(data));

  @override
  Future<void> updateTask(TaskFormData data) {
    final taskId = data.taskId;
    if (taskId == null) throw ArgumentError('An existing task id is required.');
    return _localDataSource.updateTask(taskId: taskId, values: _values(data));
  }

  Map<String, Object?> _values(TaskFormData data) {
    final title = data.title.trim();
    if (title.isEmpty) throw ArgumentError('Title is required.');
    final description = data.description?.trim();
    return {
      'title': title,
      'description': description == null || description.isEmpty
          ? null
          : description,
      'priority': data.priority.name,
    };
  }
}
