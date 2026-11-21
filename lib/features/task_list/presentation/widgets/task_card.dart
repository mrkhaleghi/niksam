import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/widgets/task_activity_sheet.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onEdit});

  final Task task;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(task.priority);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadiusDirectional.horizontal(
                      start: Radius.circular(19),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Checkbox.adaptive(
                  value: task.isCompleted,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (_) => context.read<TasksBloc>().add(
                    TasksToggleRequested(task.id),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: task.isCompleted
                                ? AppColors.muted
                                : AppColors.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (task.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            _PriorityTag(priority: task.priority),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat.yMMMd(
                                'en',
                              ).format(task.createdAt.toLocal()),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Task options',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.muted,
                  ),
                  onSelected: (choice) async {
                    if (choice == 'history') {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppColors.sheetSurface,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (_) => BlocProvider.value(
                          value: context.read<TasksBloc>(),
                          child: TaskActivitySheet(task: task),
                        ),
                      );
                    }
                    if (choice == 'delete' && context.mounted) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Delete task'),
                          content: const Text(
                            'Delete this task and its activity?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        context.read<TasksBloc>().add(
                          TasksDeleteRequested(task.id),
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'history',
                      child: ListTile(
                        leading: Icon(Icons.history_rounded),
                        title: Text('Activity'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityTag extends StatelessWidget {
  const _PriorityTag({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(priority);
    final label = switch (priority) {
      TaskPriority.low => 'Low',
      TaskPriority.medium => 'Medium',
      TaskPriority.high => 'High',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label priority',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Color _priorityColor(TaskPriority priority) => switch (priority) {
  TaskPriority.low => AppColors.lowPriority,
  TaskPriority.medium => AppColors.mediumPriority,
  TaskPriority.high => AppColors.highPriority,
};
