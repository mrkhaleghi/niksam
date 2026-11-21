import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_state.dart';

class TaskFilters extends StatelessWidget {
  const TaskFilters({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<TasksBloc, TasksState>(
    buildWhen: (previous, current) =>
        previous.priorityFilter != current.priorityFilter ||
        previous.completionFilter != current.completionFilter,
    builder: (context, state) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterRow<CompletionFilter?>(
            label: 'Status',
            selected: state.completionFilter,
            choices: const [
              (null, 'All'),
              (CompletionFilter.active, 'Open'),
              (CompletionFilter.completed, 'Done'),
            ],
            onSelected: (value) => context.read<TasksBloc>().add(
              TasksCompletionFilterChanged(value),
            ),
          ),
          _FilterRow<TaskPriority?>(
            label: 'Priority',
            selected: state.priorityFilter,
            choices: const [
              (null, 'All'),
              (TaskPriority.high, 'High'),
              (TaskPriority.medium, 'Medium'),
              (TaskPriority.low, 'Low'),
            ],
            onSelected: (value) => context.read<TasksBloc>().add(
              TasksPriorityFilterChanged(value),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.selected,
    required this.choices,
    required this.onSelected,
  });

  final String label;
  final T selected;
  final List<(T, String)> choices;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 45,
    child: Row(
      children: [
        SizedBox(
          width: 66,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.only(start: 4, end: 16),
            itemCount: choices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final (value, title) = choices[index];
              final isSelected = selected == value;
              return ChoiceChip(
                label: Text(title),
                selected: isSelected,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.white,
                selectedColor: AppColors.primary,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.chipBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                onSelected: (_) => onSelected(value),
              );
            },
          ),
        ),
      ],
    ),
  );
}
