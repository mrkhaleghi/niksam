import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';
import 'package:niksam/features/task_list/domain/repositories/task_list_repository.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

void main() {
  late _ListRepository repository;
  late TasksBloc bloc;

  setUp(() {
    repository = _ListRepository();
    bloc = TasksBloc(repository);
  });
  tearDown(() => bloc.close());

  test(
    'load exposes loading and empty; failed load can retry successfully',
    () async {
      final statuses = <TasksLoadStatus>[];
      final subscription = bloc.stream.listen(
        (state) => statuses.add(state.status),
      );
      addTearDown(subscription.cancel);
      expect(bloc.state.status, TasksLoadStatus.initial);
      await _reload(bloc);
      expect(
        statuses,
        containsAllInOrder([TasksLoadStatus.loading, TasksLoadStatus.empty]),
      );

      repository.load = () async => throw StateError('Read failed');
      await _reload(bloc);
      expect(bloc.state.status, TasksLoadStatus.failure);
      expect(bloc.state.failure, TasksFailure.load);

      repository.load = null;
      repository.tasks = [_task(1, 'Stored')];
      bloc.add(const TasksRetryRequested());
      await _until(bloc, (state) => state.status == TasksLoadStatus.success);
      expect(bloc.state.failure, isNull);
      expect(bloc.state.tasks.single.title, 'Stored');
    },
  );

  test(
    'newest query and combined filters survive reloads and stale results',
    () async {
      final oldRead = Completer<List<Task>>();
      final newRead = Completer<List<Task>>();
      final oldStarted = Completer<void>();
      final newStarted = Completer<void>();
      var reads = 0;
      repository.load = () {
        if (reads++ == 0) {
          oldStarted.complete();
          return oldRead.future;
        }
        newStarted.complete();
        return newRead.future;
      };
      final firstReload = _reload(bloc);
      await oldStarted.future;
      bloc.add(const TasksSearchChanged('b'));
      bloc.add(const TasksSearchChanged('bu'));
      bloc.add(const TasksSearchChanged('  BUILD  '));
      bloc.add(const TasksPriorityFilterChanged(TaskPriority.high));
      bloc.add(const TasksCompletionFilterChanged(CompletionFilter.active));
      await _until(
        bloc,
        (state) =>
            state.query == '  BUILD  ' &&
            state.priorityFilter == TaskPriority.high &&
            state.completionFilter == CompletionFilter.active,
      );

      final secondReload = _reload(bloc);
      await newStarted.future;
      newRead.complete([
        _task(1, 'Build app', priority: TaskPriority.high),
        _task(2, 'Build docs', priority: TaskPriority.low),
        _task(3, 'Build old', priority: TaskPriority.high, completed: true),
        _task(4, 'Other', priority: TaskPriority.high),
      ]);
      await secondReload;
      oldRead.complete([_task(99, 'Stale')]);
      await firstReload;

      expect(bloc.state.query, '  BUILD  ');
      expect(bloc.state.priorityFilter, TaskPriority.high);
      expect(bloc.state.completionFilter, CompletionFilter.active);
      expect(bloc.state.visibleTasks.map((task) => task.id), [1]);
      expect(bloc.state.tasks.map((task) => task.id), [1, 2, 3, 4]);
      bloc.add(const TasksPriorityFilterChanged(null));
      bloc.add(const TasksCompletionFilterChanged(null));
      await _until(
        bloc,
        (state) =>
            state.priorityFilter == null && state.completionFilter == null,
      );
      expect(bloc.state.visibleTasks.map((task) => task.id), [1, 2, 3]);
    },
  );

  test(
    'failed toggle restores stored state, retains filters, and retries once',
    () async {
      repository.tasks = [_task(1, 'Build app', priority: TaskPriority.high)];
      await _reload(bloc);
      bloc.add(const TasksSearchChanged('Build'));
      bloc.add(const TasksPriorityFilterChanged(TaskPriority.high));
      bloc.add(const TasksCompletionFilterChanged(CompletionFilter.active));
      repository.failWrites = true;
      bloc.add(const TasksToggleRequested(1));
      await _until(bloc, (state) => state.failure == TasksFailure.mutation);

      expect(bloc.state.tasks.single.isCompleted, isFalse);
      expect(bloc.state.visibleTasks.single.id, 1);
      expect(bloc.state.query, 'Build');
      repository.failWrites = false;
      bloc.add(const TasksRetryRequested());
      bloc.add(const TasksRetryRequested());
      await _until(
        bloc,
        (state) => state.failure == null && state.tasks.single.isCompleted,
      );
      expect(repository.toggleCalls, 2);
      expect(bloc.state.visibleTasks, isEmpty);
      expect(bloc.state.priorityFilter, TaskPriority.high);
      expect(bloc.state.completionFilter, CompletionFilter.active);
    },
  );

  test('delete failure retains the task and retry removes it', () async {
    repository.tasks = [_task(1, 'Keep until committed')];
    await _reload(bloc);
    repository.failWrites = true;
    bloc.add(const TasksDeleteRequested(1));
    await _until(bloc, (state) => state.failure == TasksFailure.mutation);
    expect(bloc.state.tasks.single.id, 1);

    repository.failWrites = false;
    bloc.add(const TasksRetryRequested());
    await _until(bloc, (state) => state.status == TasksLoadStatus.empty);
    expect(bloc.state.failure, isNull);
    expect(repository.deleteCalls, 2);
  });

  test('rapid toggles and deletion share one ordered mutation queue', () async {
    repository.tasks = [_task(1, 'Queued')];
    await _reload(bloc);
    final started = Completer<void>();
    final release = Completer<void>();
    repository.beforeToggle = () async {
      if (!started.isCompleted) {
        started.complete();
        await release.future;
      }
    };
    bloc.add(const TasksToggleRequested(1));
    await started.future;
    bloc.add(const TasksToggleRequested(1));
    bloc.add(const TasksToggleRequested(1));
    bloc.add(const TasksDeleteRequested(1));
    release.complete();
    await _until(bloc, (state) => state.status == TasksLoadStatus.empty);

    expect(repository.maxActiveWrites, 1);
    expect(repository.mutations, [
      'completed',
      'reopened',
      'completed',
      'deleted',
    ]);
  });

  test(
    'overlapping refresh cannot hide a write failure or lose its retry',
    () async {
      repository.tasks = [_task(1, 'Stored')];
      await _reload(bloc);
      final recovery = Completer<List<Task>>();
      final recoveryStarted = Completer<void>();
      var reads = 0;
      repository.load = () {
        if (reads++ == 0) {
          recoveryStarted.complete();
          return recovery.future;
        }
        return Future.value(repository.tasks);
      };
      repository.failWrites = true;
      bloc.add(const TasksToggleRequested(1));
      await recoveryStarted.future;
      await _reload(bloc);
      expect(bloc.state.failure, TasksFailure.mutation);
      recovery.complete(repository.tasks);
      repository.failWrites = false;
      bloc.add(const TasksRetryRequested());
      await _until(
        bloc,
        (state) => state.failure == null && state.tasks.single.isCompleted,
      );
      expect(repository.toggleCalls, 2);
    },
  );
}

Future<void> _reload(TasksBloc bloc) {
  final done = Completer<void>();
  bloc.add(TasksLoadRequested(completer: done));
  return done.future.timeout(const Duration(seconds: 5));
}

Future<TasksState> _until(TasksBloc bloc, bool Function(TasksState) predicate) {
  if (predicate(bloc.state)) return Future.value(bloc.state);
  return bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 5));
}

Task _task(
  int id,
  String title, {
  TaskPriority priority = TaskPriority.medium,
  bool completed = false,
}) => Task(
  id: id,
  title: title,
  description: null,
  priority: priority,
  isCompleted: completed,
  createdAt: DateTime.utc(2026),
);

class _ListRepository implements TaskListRepository {
  List<Task> tasks = [];
  Future<List<Task>> Function()? load;
  Future<void> Function()? beforeToggle;
  bool failWrites = false;
  int toggleCalls = 0;
  int deleteCalls = 0;
  int activeWrites = 0;
  int maxActiveWrites = 0;
  final mutations = <String>[];

  @override
  Future<List<Task>> getTasks() async =>
      load == null ? List.of(tasks) : await load!();

  @override
  Future<List<TaskActivity>> getActivity(int taskId) async => [];

  @override
  Future<void> toggleCompleted(int taskId) async {
    toggleCalls++;
    activeWrites++;
    maxActiveWrites = math.max(maxActiveWrites, activeWrites);
    try {
      await beforeToggle?.call();
      if (failWrites) throw StateError('Write failed');
      final old = tasks.singleWhere((task) => task.id == taskId);
      final updated = _task(
        old.id,
        old.title,
        priority: old.priority,
        completed: !old.isCompleted,
      );
      tasks = tasks.map((task) => task.id == taskId ? updated : task).toList();
      mutations.add(updated.isCompleted ? 'completed' : 'reopened');
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<void> deleteTask(int taskId) async {
    deleteCalls++;
    activeWrites++;
    maxActiveWrites = math.max(maxActiveWrites, activeWrites);
    try {
      if (failWrites) throw StateError('Write failed');
      tasks = tasks.where((task) => task.id != taskId).toList();
      mutations.add('deleted');
    } finally {
      activeWrites--;
    }
  }
}
