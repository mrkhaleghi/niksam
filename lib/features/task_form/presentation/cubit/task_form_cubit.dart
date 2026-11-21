import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_form/domain/repositories/task_form_repository.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_state.dart';

class TaskFormCubit extends Cubit<TaskFormState> {
  TaskFormCubit(this._repository, {TaskFormData? initialData})
    : super(
        TaskFormState(
          data:
              initialData ??
              const TaskFormData(
                title: '',
                description: null,
                priority: TaskFormPriority.medium,
              ),
        ),
      );

  final TaskFormRepository _repository;

  void titleChanged(String title) => _change(title: title);
  void descriptionChanged(String description) =>
      _change(description: description);
  void priorityChanged(TaskFormPriority priority) =>
      _change(priority: priority);

  void _change({
    String? title,
    String? description,
    TaskFormPriority? priority,
  }) {
    if (isClosed || state.status == TaskFormStatus.saving) return;
    final previous = state.data;
    final next = TaskFormData(
      taskId: previous.taskId,
      title: title ?? previous.title,
      description: description ?? previous.description,
      priority: priority ?? previous.priority,
    );
    if (next.title == previous.title &&
        next.description == previous.description &&
        next.priority == previous.priority) {
      return;
    }
    emit(TaskFormState(data: next));
  }

  Future<bool> save() async {
    if (isClosed ||
        state.status == TaskFormStatus.saving ||
        state.status == TaskFormStatus.success) {
      return false;
    }
    final data = state.data;
    if (data.title.trim().isEmpty) {
      emit(TaskFormState(data: data, status: TaskFormStatus.failure));
      return false;
    }
    emit(TaskFormState(data: data, status: TaskFormStatus.saving));
    try {
      if (data.taskId == null) {
        await _repository.createTask(data);
      } else {
        await _repository.updateTask(data);
      }
      if (!isClosed) {
        emit(TaskFormState(data: data, status: TaskFormStatus.success));
      }
      return true;
    } catch (_) {
      // Keep the draft for retry. The list continues to show committed data.
      if (!isClosed) {
        emit(TaskFormState(data: data, status: TaskFormStatus.failure));
      }
      return false;
    }
  }
}
