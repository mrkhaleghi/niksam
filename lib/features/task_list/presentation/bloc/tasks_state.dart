import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';

enum TasksLoadStatus { initial, loading, empty, success, failure }

enum TasksFailure { load, mutation }

enum CompletionFilter { active, completed }

enum ActivityLoadStatus { initial, loading, empty, success, failure }

class TasksState {
  TasksState({
    List<Task> tasks = const [],
    this.query = '',
    this.priorityFilter,
    this.completionFilter,
    this.status = TasksLoadStatus.initial,
    this.failure,
    this.activityTaskId,
    List<TaskActivity> activity = const [],
    this.activityStatus = ActivityLoadStatus.initial,
  }) : tasks = List.unmodifiable(tasks),
       activity = List.unmodifiable(activity);

  final List<Task> tasks;
  final String query;
  final TaskPriority? priorityFilter;
  final CompletionFilter? completionFilter;
  final TasksLoadStatus status;
  final TasksFailure? failure;
  final int? activityTaskId;
  final List<TaskActivity> activity;
  final ActivityLoadStatus activityStatus;

  List<Task> get visibleTasks {
    final normalizedQuery = query.trim().toLowerCase();
    return tasks.where((task) {
      final matchesQuery = normalizedQuery.isEmpty ||
          task.title.toLowerCase().contains(normalizedQuery);
      final matchesPriority = priorityFilter == null ||
          task.priority == priorityFilter;
      final matchesCompletion = switch (completionFilter) {
        CompletionFilter.active => !task.isCompleted,
        CompletionFilter.completed => task.isCompleted,
        null => true,
      };
      return matchesQuery && matchesPriority && matchesCompletion;
    }).toList(growable: false);
  }

  TasksState copyWith({
    List<Task>? tasks,
    String? query,
    TaskPriority? priorityFilter,
    bool clearPriorityFilter = false,
    CompletionFilter? completionFilter,
    bool clearCompletionFilter = false,
    TasksLoadStatus? status,
    TasksFailure? failure,
    bool clearFailure = false,
    int? activityTaskId,
    List<TaskActivity>? activity,
    ActivityLoadStatus? activityStatus,
  }) =>
      TasksState(
        tasks: tasks ?? this.tasks,
        query: query ?? this.query,
        priorityFilter: clearPriorityFilter
            ? null
            : priorityFilter ?? this.priorityFilter,
        completionFilter: clearCompletionFilter
            ? null
            : completionFilter ?? this.completionFilter,
        status: status ?? this.status,
        failure: clearFailure ? null : failure ?? this.failure,
        activityTaskId: activityTaskId ?? this.activityTaskId,
        activity: activity ?? this.activity,
        activityStatus: activityStatus ?? this.activityStatus,
      );
}
