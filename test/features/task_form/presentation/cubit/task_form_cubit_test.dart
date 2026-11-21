import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_form/domain/repositories/task_form_repository.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_cubit.dart';
import 'package:niksam/features/task_form/presentation/cubit/task_form_state.dart';

void main() {
  late _FormRepository repository;
  late TaskFormCubit cubit;

  setUp(() {
    repository = _FormRepository();
    cubit = TaskFormCubit(repository);
  });
  tearDown(() => cubit.close());

  test(
    'create emits saving then success and forwards the current draft',
    () async {
      final statuses = cubit.stream
          .map((state) => state.status)
          .where((status) => status != TaskFormStatus.initial)
          .take(2)
          .toList();
      cubit.titleChanged('New task');
      cubit.descriptionChanged('Details');
      cubit.priorityChanged(TaskFormPriority.high);

      expect(await cubit.save(), isTrue);
      expect(await statuses, [TaskFormStatus.saving, TaskFormStatus.success]);
      expect(repository.created.single.title, 'New task');
      expect(repository.created.single.description, 'Details');
      expect(repository.created.single.priority, TaskFormPriority.high);
      expect(repository.updated, isEmpty);
    },
  );

  test(
    'edit saves the existing id through update rather than create',
    () async {
      await cubit.close();
      cubit = TaskFormCubit(
        repository,
        initialData: const TaskFormData(
          taskId: 12,
          title: 'Original',
          description: null,
          priority: TaskFormPriority.low,
        ),
      );
      cubit.titleChanged('Edited');

      expect(await cubit.save(), isTrue);
      expect(repository.updated.single.taskId, 12);
      expect(repository.updated.single.title, 'Edited');
      expect(repository.created, isEmpty);
    },
  );

  test('blank title fails without calling the repository', () async {
    cubit.titleChanged('   ');
    expect(await cubit.save(), isFalse);
    expect(cubit.state.status, TaskFormStatus.failure);
    expect(repository.created, isEmpty);
    expect(repository.updated, isEmpty);
  });

  test('failed save keeps the draft and retries it once', () async {
    repository.create = (_) async => throw StateError('Disk full');
    cubit.titleChanged('Retry me');
    cubit.priorityChanged(TaskFormPriority.high);
    final draft = cubit.state.data;

    expect(await cubit.save(), isFalse);
    expect(cubit.state.status, TaskFormStatus.failure);
    expect(cubit.state.data, same(draft));

    repository.create = (_) async => 1;
    expect(await cubit.save(), isTrue);
    expect(cubit.state.status, TaskFormStatus.success);
    expect(repository.created, [same(draft), same(draft)]);
  });

  test('rapid saves make one write and freeze the submitted draft', () async {
    final pending = Completer<int>();
    repository.create = (_) => pending.future;
    cubit.titleChanged('Submitted');
    final firstSave = cubit.save();

    expect(cubit.state.status, TaskFormStatus.saving);
    expect(await cubit.save(), isFalse);
    expect(await cubit.save(), isFalse);
    cubit.titleChanged('Ignored while saving');
    cubit.descriptionChanged('Ignored');
    cubit.priorityChanged(TaskFormPriority.high);
    expect(cubit.state.data.title, 'Submitted');
    expect(cubit.state.data.description, isNull);
    expect(cubit.state.data.priority, TaskFormPriority.medium);

    pending.complete(1);
    expect(await firstSave, isTrue);
    expect(await cubit.save(), isFalse);
    expect(repository.created.length, 1);
  });

  test('a write finishing after disposal does not emit or throw', () async {
    final pending = Completer<int>();
    repository.create = (_) => pending.future;
    cubit.titleChanged('Pending');
    final save = cubit.save();
    await cubit.close();
    pending.completeError(StateError('Disk full'));

    expect(await save, isFalse);
    expect(cubit.isClosed, isTrue);
  });
}

class _FormRepository implements TaskFormRepository {
  final created = <TaskFormData>[];
  final updated = <TaskFormData>[];
  Future<int> Function(TaskFormData) create = (_) async => 1;

  @override
  Future<int> createTask(TaskFormData data) {
    created.add(data);
    return create(data);
  }

  @override
  Future<void> updateTask(TaskFormData data) async {
    updated.add(data);
  }
}
