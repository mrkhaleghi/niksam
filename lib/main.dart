import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:niksam/core/di/injection.dart';
import 'package:niksam/core/theme/app_colors.dart';
import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_form/domain/repositories/task_form_repository.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_cubit.dart';
import 'package:niksam/features/task_form/presentation/pages/task_form_page.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/repositories/task_list_repository.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_bloc.dart';
import 'package:niksam/features/task_list/presentation/bloc/tasks_event.dart';
import 'package:niksam/features/task_list/presentation/pages/tasks_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskApp());
}

class TaskApp extends StatefulWidget {
  const TaskApp({super.key});

  @override
  State<TaskApp> createState() => _TaskAppState();
}

class _TaskAppState extends State<TaskApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = configureDependencies();
  }

  @override
  void dispose() {
    unawaited(_releaseDependencies());
    super.dispose();
  }

  Future<void> _releaseDependencies() async {
    try {
      await _initialization;
    } catch (_) {
      // Database opening may have failed before registration.
    }
    await getIt.reset();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tasks',
    debugShowCheckedModeBanner: false,
    locale: const Locale('en'),
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.canvas,
      ),
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.appBarTitle,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    ),
    home: FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load tasks.'),
                  TextButton(
                    onPressed: () => setState(() {
                      _initialization = configureDependencies();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return BlocProvider(
          create: (_) =>
              TasksBloc(getIt<TaskListRepository>())
                ..add(const TasksLoadRequested()),
          child: TasksPage(
            openTaskForm: (Task? task) => BlocProvider(
              create: (_) => TaskFormCubit(
                getIt<TaskFormRepository>(),
                initialData: task == null
                    ? null
                    : TaskFormData(
                        taskId: task.id,
                        title: task.title,
                        description: task.description,
                        priority: _toFormPriority(task.priority),
                      ),
              ),
              child: const TaskFormPage(),
            ),
          ),
        );
      },
    ),
  );
}

TaskFormPriority _toFormPriority(TaskPriority priority) => switch (priority) {
  TaskPriority.low => TaskFormPriority.low,
  TaskPriority.medium => TaskFormPriority.medium,
  TaskPriority.high => TaskFormPriority.high,
};
