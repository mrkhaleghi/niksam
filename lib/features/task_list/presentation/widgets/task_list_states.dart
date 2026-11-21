import 'package:flutter/material.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

class TaskEmptyState extends StatelessWidget {
  const TaskEmptyState({
    super.key,
    required this.hasTasks,
    required this.hasQuery,
  });

  final bool hasTasks;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              color: AppColors.iconSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.note_alt_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasQuery || hasTasks ? 'No matching tasks' : 'No tasks yet',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery || hasTasks
                ? 'Try a different search or filter.'
                : 'Add a task to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class TaskFailureBanner extends StatelessWidget {
  const TaskFailureBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.errorSurface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.errorText, fontSize: 12),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class TaskErrorView extends StatelessWidget {
  const TaskErrorView({super.key, required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.muted,
            size: 42,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

String taskFailureMessage(TasksFailure failure) => switch (failure) {
  TasksFailure.load => 'Could not load tasks.',
  TasksFailure.mutation =>
    'Save failed. Your changes were not saved. Try again.',
};
