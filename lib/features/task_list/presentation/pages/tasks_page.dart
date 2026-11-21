import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';
import 'package:niksam/features/task_list/presentation/widgets/task_card.dart';
import 'package:niksam/features/task_list/presentation/widgets/task_count_badge.dart';
import 'package:niksam/features/task_list/presentation/widgets/task_filters.dart';
import 'package:niksam/features/task_list/presentation/widgets/task_list_states.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key, required this.openTaskForm});

  final Widget Function(Task? task) openTaskForm;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openTaskForm({Task? task}) async {
    final bloc = context.read<TasksBloc>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => widget.openTaskForm(task)),
    );
    if (saved == true && mounted) bloc.add(const TasksLoadRequested());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tasks')),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 3,
      onPressed: () => _openTaskForm(),
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New task',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: BlocBuilder<TasksBloc, TasksState>(
                    buildWhen: (previous, current) =>
                        previous.tasks.length != current.tasks.length,
                    builder: (context, state) =>
                        TaskCountBadge(count: state.tasks.length),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (query) =>
                      context.read<TasksBloc>().add(TasksSearchChanged(query)),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search tasks',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const TaskFilters(),
          Expanded(
            child: BlocBuilder<TasksBloc, TasksState>(
              buildWhen: (previous, current) =>
                  !listEquals(previous.tasks, current.tasks) ||
                  previous.query != current.query ||
                  previous.priorityFilter != current.priorityFilter ||
                  previous.completionFilter != current.completionFilter ||
                  previous.status != current.status ||
                  previous.failure != current.failure,
              builder: (context, state) {
                if ((state.status == TasksLoadStatus.initial ||
                        state.status == TasksLoadStatus.loading) &&
                    state.tasks.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == TasksLoadStatus.failure &&
                    state.tasks.isEmpty) {
                  return TaskErrorView(
                    message: taskFailureMessage(state.failure!),
                    retry: () => context.read<TasksBloc>().add(
                      const TasksRetryRequested(),
                    ),
                  );
                }
                final tasks = state.visibleTasks;
                if (tasks.isEmpty) {
                  final emptyState = TaskEmptyState(
                    hasTasks: state.tasks.isNotEmpty,
                    hasQuery:
                        state.query.trim().isNotEmpty ||
                        state.priorityFilter != null ||
                        state.completionFilter != null,
                  );
                  if (state.failure == null) return emptyState;
                  return Column(
                    children: [
                      TaskFailureBanner(
                        message: taskFailureMessage(state.failure!),
                        onRetry: () => context.read<TasksBloc>().add(
                          const TasksRetryRequested(),
                        ),
                      ),
                      Expanded(child: emptyState),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (state.failure != null)
                      TaskFailureBanner(
                        message: taskFailureMessage(state.failure!),
                        onRetry: () => context.read<TasksBloc>().add(
                          const TasksRetryRequested(),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () {
                          final completer = Completer<void>();
                          context.read<TasksBloc>().add(
                            TasksLoadRequested(completer: completer),
                          );
                          return completer.future;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                          itemCount: tasks.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => TaskCard(
                            key: ValueKey(tasks[index].id),
                            task: tasks[index],
                            onEdit: () => _openTaskForm(task: tasks[index]),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
