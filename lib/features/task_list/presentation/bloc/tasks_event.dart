import 'dart:async';

import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

sealed class TasksEvent {
  const TasksEvent();
}

final class TasksLoadRequested extends TasksEvent {
  const TasksLoadRequested({this.completer});

  final Completer<void>? completer;
}

final class TasksSearchChanged extends TasksEvent {
  const TasksSearchChanged(this.query);

  final String query;
}

final class TasksPriorityFilterChanged extends TasksEvent {
  const TasksPriorityFilterChanged(this.priority);

  final TaskPriority? priority;
}

final class TasksCompletionFilterChanged extends TasksEvent {
  const TasksCompletionFilterChanged(this.completion);

  final CompletionFilter? completion;
}

final class TasksToggleRequested extends TasksEvent {
  const TasksToggleRequested(this.taskId);

  final int taskId;
}

final class TasksDeleteRequested extends TasksEvent {
  const TasksDeleteRequested(this.taskId);

  final int taskId;
}

final class TasksRetryRequested extends TasksEvent {
  const TasksRetryRequested();
}

final class TasksActivityRequested extends TasksEvent {
  const TasksActivityRequested(this.taskId);

  final int taskId;
}
