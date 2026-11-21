import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_cubit.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_state.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final bool _isEditing;

  @override
  void initState() {
    super.initState();
    final initialData = context.read<TaskFormCubit>().state.data;
    _isEditing = initialData.taskId != null;
    _titleController = TextEditingController(text: initialData.title);
    _descriptionController = TextEditingController(
      text: initialData.description ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await context.read<TaskFormCubit>().save();
    if (!mounted) return;
    if (success) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final (saveStatus, selectedPriority) = context.select(
      (TaskFormCubit cubit) => (cubit.state.status, cubit.state.data.priority),
    );
    final saving = saveStatus == TaskFormStatus.saving;
    final saveFailed = saveStatus == TaskFormStatus.failure;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit task' : 'New task'),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: saving ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const _SectionLabel(
                icon: Icons.short_text_rounded,
                title: 'Title',
                requiredMark: true,
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.formBorder),
                ),
                child: TextFormField(
                  controller: _titleController,
                  enabled: !saving,
                  onChanged: context.read<TaskFormCubit>().titleChanged,
                  autofocus: !_isEditing,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: 'Task title',
                    counterText: '',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Title is required.'
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(
                icon: Icons.notes_rounded,
                title: 'Description (Optional)',
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: AppColors.formBorder),
                ),
                child: TextFormField(
                  controller: _descriptionController,
                  enabled: !saving,
                  onChanged: context.read<TaskFormCubit>().descriptionChanged,
                  minLines: 4,
                  maxLines: 7,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Add details (optional)',
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const _SectionLabel(icon: Icons.flag_rounded, title: 'Priority'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TaskFormPriority.values.map((priority) {
                  final selected = selectedPriority == priority;
                  final color = _priorityColor(priority);
                  return ChoiceChip(
                    avatar: Icon(
                      _priorityIcon(priority),
                      size: 17,
                      color: selected ? AppColors.white : color,
                    ),
                    label: Text(_priorityName(priority)),
                    selected: selected,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: selected ? AppColors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    backgroundColor: AppColors.white,
                    selectedColor: color,
                    side: BorderSide(
                      color: selected ? color : AppColors.selectedFormBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    onSelected: saving
                        ? null
                        : (_) => context.read<TaskFormCubit>().priorityChanged(
                            priority,
                          ),
                  );
                }).toList(),
              ),
              if (saveFailed) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Save failed. Your changes were not saved. Try again.',
                    style: TextStyle(color: AppColors.formErrorText),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.canvas,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  saving ? 'Saving…' : 'Save',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.icon,
    this.requiredMark = false,
  });

  final IconData? icon;
  final String title;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 7),
      ],
      Text(
        title,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (requiredMark)
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 4),
          child: Text(
            '*',
            style: TextStyle(
              color: AppColors.highPriority,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
    ],
  );
}

Color _priorityColor(TaskFormPriority priority) => switch (priority) {
  TaskFormPriority.low => AppColors.lowPriority,
  TaskFormPriority.medium => AppColors.mediumPriority,
  TaskFormPriority.high => AppColors.highPriority,
};

IconData _priorityIcon(TaskFormPriority priority) => switch (priority) {
  TaskFormPriority.low => Icons.south_rounded,
  TaskFormPriority.medium => Icons.remove_rounded,
  TaskFormPriority.high => Icons.north_rounded,
};

String _priorityName(TaskFormPriority priority) => switch (priority) {
  TaskFormPriority.low => 'Low',
  TaskFormPriority.medium => 'Medium',
  TaskFormPriority.high => 'High',
};
