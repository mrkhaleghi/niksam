import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/features/task_list/domain/entities/task_list_query.dart';
import 'package:niksam/features/task_list/domain/repositories/task_list_repository.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

class TasksBloc extends Bloc<TasksEvent, TasksState> {
  TasksBloc(this._repository) : super(TasksState()) {
    on<TasksLoadRequested>(_onLoadRequested);
    on<TasksSearchChanged>(_onSearchChanged);
    on<TasksPriorityFilterChanged>(_onPriorityFilterChanged);
    on<TasksCompletionFilterChanged>(_onCompletionFilterChanged);
    on<TasksToggleRequested>(_onToggleRequested);
    on<TasksDeleteRequested>(_onDeleteRequested);
    on<TasksRetryRequested>(_onRetryRequested);
    on<TasksActivityRequested>(_onActivityRequested);
  }

  final TaskListRepository _repository;
  Future<void> _mutationQueue = Future<void>.value();
  Future<void> Function()? _lastFailedMutation;
  int _loadRequest = 0;
  bool _retryInProgress = false;
  int _activityRequest = 0;

  Future<void> _onActivityRequested(
    TasksActivityRequested event,
    Emitter<TasksState> emit,
  ) async {
    final request = ++_activityRequest;
    emit(
      state.copyWith(
        activityTaskId: event.taskId,
        activity: const [],
        activityStatus: ActivityLoadStatus.loading,
      ),
    );
    try {
      final activity = await _repository.getActivity(event.taskId);
      if (isClosed || emit.isDone || request != _activityRequest) return;
      emit(
        state.copyWith(
          activity: activity,
          activityStatus: activity.isEmpty
              ? ActivityLoadStatus.empty
              : ActivityLoadStatus.success,
        ),
      );
    } catch (_) {
      if (isClosed || emit.isDone || request != _activityRequest) return;
      emit(state.copyWith(activityStatus: ActivityLoadStatus.failure));
    }
  }

  Future<void> _onSearchChanged(
    TasksSearchChanged event,
    Emitter<TasksState> emit,
  ) async {
    if (event.query == state.query) return;
    emit(
      state.copyWith(
        query: event.query,
        tasks: const [],
        status: TasksLoadStatus.loading,
      ),
    );
    await _load(emit);
  }

  Future<void> _onPriorityFilterChanged(
    TasksPriorityFilterChanged event,
    Emitter<TasksState> emit,
  ) async {
    if (event.priority == state.priorityFilter) return;
    emit(
      state.copyWith(
        priorityFilter: event.priority,
        clearPriorityFilter: event.priority == null,
        tasks: const [],
        status: TasksLoadStatus.loading,
      ),
    );
    await _load(emit);
  }

  Future<void> _onCompletionFilterChanged(
    TasksCompletionFilterChanged event,
    Emitter<TasksState> emit,
  ) async {
    if (event.completion == state.completionFilter) return;
    emit(
      state.copyWith(
        completionFilter: event.completion,
        clearCompletionFilter: event.completion == null,
        tasks: const [],
        status: TasksLoadStatus.loading,
      ),
    );
    await _load(emit);
  }

  Future<void> _onLoadRequested(
    TasksLoadRequested event,
    Emitter<TasksState> emit,
  ) async {
    try {
      await _load(emit);
    } finally {
      if (event.completer != null && !event.completer!.isCompleted) {
        event.completer!.complete();
      }
    }
  }

  Future<void> _load(Emitter<TasksState> emit) async {
    if (isClosed || emit.isDone) return;
    final request = ++_loadRequest;
    final query = TaskListQuery(
      title: state.query,
      priority: state.priorityFilter,
      completed: switch (state.completionFilter) {
        CompletionFilter.active => false,
        CompletionFilter.completed => true,
        null => null,
      },
    );
    emit(state.copyWith(status: TasksLoadStatus.loading));
    try {
      final result = await _repository.getTasks(query: query);
      if (request != _loadRequest || isClosed || emit.isDone) return;
      emit(
        state.copyWith(
          tasks: result.tasks,
          totalCount: result.totalCount,
          status: result.tasks.isEmpty
              ? TasksLoadStatus.empty
              : TasksLoadStatus.success,
          failure: _lastFailedMutation == null ? null : TasksFailure.mutation,
          clearFailure: _lastFailedMutation == null,
        ),
      );
    } catch (_) {
      if (request != _loadRequest || isClosed || emit.isDone) return;
      emit(
        state.copyWith(
          status: TasksLoadStatus.failure,
          failure: _lastFailedMutation == null
              ? TasksFailure.load
              : TasksFailure.mutation,
        ),
      );
    }
  }

  Future<void> _onToggleRequested(
    TasksToggleRequested event,
    Emitter<TasksState> emit,
  ) => _serialize(() => _repository.toggleCompleted(event.taskId), emit);

  Future<void> _onDeleteRequested(
    TasksDeleteRequested event,
    Emitter<TasksState> emit,
  ) => _serialize(() => _repository.deleteTask(event.taskId), emit);

  Future<void> _onRetryRequested(
    TasksRetryRequested event,
    Emitter<TasksState> emit,
  ) async {
    if (_retryInProgress) return;
    final failedMutation = _lastFailedMutation;
    if (failedMutation == null) {
      await _load(emit);
      return;
    }
    _retryInProgress = true;
    try {
      await _serialize(failedMutation, emit, retry: true);
    } finally {
      _retryInProgress = false;
    }
  }

  Future<void> _serialize(
    Future<void> Function() operation,
    Emitter<TasksState> emit, {
    bool retry = false,
  }) async {
    final next = _mutationQueue.then((_) async {
      if (isClosed || emit.isDone) return;
      // A newer successful action can supersede a queued retry.
      if (retry && !identical(operation, _lastFailedMutation)) return;
      try {
        await operation();
        _lastFailedMutation = null;
        await _load(emit);
        final activityTaskId = state.activityTaskId;
        if (!isClosed && activityTaskId != null) {
          add(TasksActivityRequested(activityTaskId));
        }
      } catch (_) {
        _lastFailedMutation = operation;
        await _load(emit);
      }
    });
    _mutationQueue = next.catchError((Object _) {});
    await next;
  }
}
