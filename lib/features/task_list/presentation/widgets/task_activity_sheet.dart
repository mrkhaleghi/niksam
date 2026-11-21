import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

class TaskActivitySheet extends StatefulWidget {
  const TaskActivitySheet({super.key, required this.task});

  final Task task;

  @override
  State<TaskActivitySheet> createState() => _TaskActivitySheetState();
}

class _TaskActivitySheetState extends State<TaskActivitySheet> {
  @override
  void initState() {
    super.initState();
    context.read<TasksBloc>().add(TasksActivityRequested(widget.task.id));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .72,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.timelineHandle,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.iconSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Activity',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: BlocBuilder<TasksBloc, TasksState>(
                buildWhen: (previous, current) =>
                    previous.activityStatus != current.activityStatus ||
                    previous.activityTaskId != current.activityTaskId ||
                    !listEquals(previous.activity, current.activity),
                builder: (context, state) {
                  if (state.activityTaskId != widget.task.id ||
                      state.activityStatus == ActivityLoadStatus.initial ||
                      state.activityStatus == ActivityLoadStatus.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.activityStatus == ActivityLoadStatus.failure) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Could not load activity.'),
                          TextButton(
                            onPressed: () => context.read<TasksBloc>().add(
                              TasksActivityRequested(widget.task.id),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  final events = state.activity;
                  if (events.isEmpty) {
                    return const Center(child: Text('No activity yet.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: AppColors.iconSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _icon(event.type),
                                size: 17,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _label(event),
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    DateFormat.yMMMd('en').add_jm().format(
                                      event.occurredAt.toLocal(),
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  IconData _icon(TaskActivityType type) => switch (type) {
    TaskActivityType.created => Icons.add_rounded,
    TaskActivityType.priorityChanged => Icons.flag_outlined,
    TaskActivityType.completed => Icons.check_rounded,
    TaskActivityType.reopened => Icons.refresh_rounded,
  };

  String _label(TaskActivity event) => switch (event.type) {
    TaskActivityType.created => 'Task created',
    TaskActivityType.priorityChanged =>
      'Priority changed: ${_priority(event.oldValue)} → ${_priority(event.newValue)}',
    TaskActivityType.completed => 'Task completed',
    TaskActivityType.reopened => 'Task reopened',
  };

  String _priority(String? value) => switch (value) {
    'low' => 'Low',
    'medium' => 'Medium',
    'high' => 'High',
    _ => value ?? '',
  };
}
