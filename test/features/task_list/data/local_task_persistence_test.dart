import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:niksam/core/database/app_database.dart';
import 'package:niksam/core/database/local_write_coordinator.dart';
import 'package:niksam/features/task_form/data/repositories/task_form_repository_impl.dart';
import 'package:niksam/features/task_form/data/services/local/task_form_local_data_source.dart';
import 'package:niksam/features/task_form/domain/entities/task_form_data.dart';
import 'package:niksam/features/task_list/data/repositories/task_list_repository_impl.dart';
import 'package:niksam/features/task_list/data/services/local/task_list_local_data_source.dart';
import 'package:niksam/features/task_list/domain/entities/task_activity.dart';
import 'package:niksam/features/task_list/domain/entities/task.dart';
import 'package:niksam/features/task_list/domain/entities/task_list_query.dart';

void main() {
  sqfliteFfiInit();

  late Directory directory;
  late Database database;
  late LocalWriteCoordinator writes;
  late TaskFormRepositoryImpl form;
  late TaskListRepositoryImpl list;
  late String path;

  TaskFormRepositoryImpl formRepository({bool failWrites = false}) =>
      TaskFormRepositoryImpl(
        SqfliteTaskFormLocalDataSource(
          database,
          writes,
          failWrites: failWrites,
        ),
      );

  TaskListRepositoryImpl listRepository({bool failWrites = false}) =>
      TaskListRepositoryImpl(
        TaskListLocalDataSource(database, writes, failWrites: failWrites),
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('niksam_persistence_');
    path = '${directory.path}/tasks.db';
    database = await AppDatabase.open(factory: databaseFactoryFfi, path: path);
    writes = LocalWriteCoordinator();
    form = formRepository();
    list = listRepository();
  });

  tearDown(() async {
    await writes.settled;
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'schema, task and history survive closing and reopening a disk database',
    () async {
      final id = await form.createTask(_draft());
      await form.updateTask(_draft(id: id, priority: TaskFormPriority.high));
      await list.toggleCompleted(id);
      final storedTasks = await database.query('tasks');
      final storedEvents = await database.query(
        'activity_events',
        orderBy: 'id',
      );

      await database.close();
      database = await AppDatabase.open(
        factory: databaseFactoryFfi,
        path: path,
      );

      list = listRepository();
      expect(await database.getVersion(), AppDatabase.schemaVersion);
      expect(
        (await database.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(await database.query('tasks'), storedTasks);
      expect(
        await database.query('activity_events', orderBy: 'id'),
        storedEvents,
      );
      final task = (await list.getTasks()).tasks.single;
      expect(task.id, id);
      expect(task.isCompleted, isTrue);
      expect(task.createdAt.isUtc, isTrue);
    },
  );

  test(
    'priority edits record old and new values; text edits add no activity',
    () async {
      final id = await form.createTask(_draft());
      await form.updateTask(_draft(id: id, priority: TaskFormPriority.high));
      await form.updateTask(
        _draft(id: id, title: 'Renamed', priority: TaskFormPriority.high),
      );

      final events = await list.getActivity(id);
      expect(events.map((event) => event.type), [
        TaskActivityType.created,
        TaskActivityType.priorityChanged,
      ]);
      expect(events.last.oldValue, 'medium');
      expect(events.last.newValue, 'high');
      expect((await list.getTasks()).tasks.single.title, 'Renamed');
    },
  );

  for (final operation in ['create', 'edit', 'toggle', 'delete']) {
    test(
      '$operation failure rolls back both tables and allows retry',
      () async {
        final id = await form.createTask(_draft());
        final beforeTasks = await database.query('tasks');
        final beforeHistory = await database.query(
          'activity_events',
          orderBy: 'id',
        );
        final failingForm = formRepository(failWrites: true);
        final failingList = listRepository(failWrites: true);

        final Future<void> Function() fail = switch (operation) {
          'create' => () async {
            await failingForm.createTask(_draft(title: 'Another'));
          },
          'edit' => () => failingForm.updateTask(
            _draft(id: id, priority: TaskFormPriority.high),
          ),
          'toggle' => () => failingList.toggleCompleted(id),
          _ => () => failingList.deleteTask(id),
        };
        await expectLater(fail(), throwsStateError);
        expect(await database.query('tasks'), beforeTasks);
        expect(
          await database.query('activity_events', orderBy: 'id'),
          beforeHistory,
        );

        switch (operation) {
          case 'create':
            await form.createTask(_draft(title: 'Another'));
            expect((await list.getTasks()).tasks.length, 2);
            expect((await database.query('activity_events')).length, 2);
          case 'edit':
            await form.updateTask(
              _draft(id: id, priority: TaskFormPriority.high),
            );
            expect((await list.getActivity(id)).last.newValue, 'high');
          case 'toggle':
            await list.toggleCompleted(id);
            expect((await list.getTasks()).tasks.single.isCompleted, isTrue);
            expect(
              (await list.getActivity(id)).last.type,
              TaskActivityType.completed,
            );
          case 'delete':
            await list.deleteTask(id);
            expect((await list.getTasks()).tasks, isEmpty);
            expect(await database.query('activity_events'), isEmpty);
        }
      },
    );
  }

  test('an actual history insert error rolls back the task update', () async {
    final id = await form.createTask(_draft());
    final beforeTasks = await database.query('tasks');
    final beforeEvents = await database.query('activity_events');
    await database.execute('''
      CREATE TEMP TRIGGER reject_history BEFORE INSERT ON activity_events
      BEGIN SELECT RAISE(ABORT, 'history unavailable'); END
    ''');

    await expectLater(
      form.updateTask(_draft(id: id, priority: TaskFormPriority.high)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await database.query('tasks'), beforeTasks);
    expect(await database.query('activity_events'), beforeEvents);

    await database.execute('DROP TRIGGER reject_history');
    await form.updateTask(_draft(id: id, priority: TaskFormPriority.high));
    expect((await list.getActivity(id)).length, 2);
  });

  test(
    'normalized no-op saves write nothing even with write failures enabled',
    () async {
      final id = await form.createTask(_draft());
      final beforeTasks = await database.query('tasks');
      final beforeEvents = await database.query('activity_events');
      final beforeChanges = await database.rawQuery('SELECT total_changes()');

      await formRepository(
        failWrites: true,
      ).updateTask(_draft(id: id, title: '  Task  ', description: '   '));
      await form.updateTask(_draft(id: id));

      expect(await database.rawQuery('SELECT total_changes()'), beforeChanges);
      expect(await database.query('tasks'), beforeTasks);
      expect(await database.query('activity_events'), beforeEvents);
    },
  );

  test(
    'rapid toggles use persisted state and alternate completion events',
    () async {
      final id = await form.createTask(_draft());
      await Future.wait(List.generate(41, (_) => list.toggleCompleted(id)));

      final events = await list.getActivity(id);
      expect(events.map((event) => event.type), [
        TaskActivityType.created,
        ...List.generate(
          41,
          (index) => index.isEven
              ? TaskActivityType.completed
              : TaskActivityType.reopened,
        ),
      ]);
      expect((await list.getTasks()).tasks.single.isCompleted, isTrue);
      for (var i = 1; i < events.length; i++) {
        expect(
          events[i].occurredAt.isBefore(events[i - 1].occurredAt),
          isFalse,
        );
        expect(events[i].id, greaterThan(events[i - 1].id));
      }
    },
  );

  test(
    'both features share write ordering and edits preserve completion',
    () async {
      final id = await form.createTask(_draft());
      await Future.wait<void>([
        form.updateTask(_draft(id: id, priority: TaskFormPriority.high)),
        list.toggleCompleted(id),
        form.updateTask(_draft(id: id, priority: TaskFormPriority.low)),
        list.toggleCompleted(id),
      ]);
      final events = await list.getActivity(id);
      expect(events.map((event) => event.type), [
        TaskActivityType.created,
        TaskActivityType.priorityChanged,
        TaskActivityType.completed,
        TaskActivityType.priorityChanged,
        TaskActivityType.reopened,
      ]);
      expect(events[3].oldValue, 'high');
      expect(events[3].newValue, 'low');
      expect((await list.getTasks()).tasks.single.isCompleted, isFalse);
    },
  );

  test(
    'SQL combines title, priority and completion while keeping total count',
    () async {
      final openHigh = await form.createTask(
        _draft(title: 'Build app', priority: TaskFormPriority.high),
      );
      final doneHigh = await form.createTask(
        _draft(title: 'Build done', priority: TaskFormPriority.high),
      );
      await list.toggleCompleted(doneHigh);
      final low = await form.createTask(
        _draft(title: 'Build docs', priority: TaskFormPriority.low),
      );
      await form.createTask(
        _draft(
          title: 'Other',
          description: 'Build app',
          priority: TaskFormPriority.high,
        ),
      );

      final open = await list.getTasks(
        query: const TaskListQuery(
          title: '  bUiLd  ',
          priority: TaskPriority.high,
          completed: false,
        ),
      );
      expect(open.tasks.map((task) => task.id), [openHigh]);
      expect(open.totalCount, 4);
      final done = await list.getTasks(
        query: const TaskListQuery(
          title: 'build',
          priority: TaskPriority.high,
          completed: true,
        ),
      );
      expect(done.tasks.map((task) => task.id), [doneHigh]);
      expect(
        (await list.getTasks(
          query: const TaskListQuery(title: 'build'),
        )).tasks.map((task) => task.id),
        [low, doneHigh, openHigh],
      );
      expect((await list.getTasks()).tasks.length, 4);
    },
  );

  test(
    'SQL treats wildcard and quote characters as literal title input',
    () async {
      final percent = await form.createTask(_draft(title: '100% ready'));
      final underscore = await form.createTask(_draft(title: 'a_b'));
      final backslash = await form.createTask(_draft(title: r'folder\file'));
      final quote = await form.createTask(_draft(title: "Owner's task"));
      await form.createTask(_draft(title: '1000 ready and axb'));
      for (final entry in {
        '%': percent,
        '_': underscore,
        r'\': backslash,
        "'": quote,
      }.entries) {
        final result = await list.getTasks(
          query: TaskListQuery(title: entry.key),
        );
        expect(result.tasks.map((task) => task.id), [entry.value]);
      }
      final injection = await list.getTasks(
        query: const TaskListQuery(title: "%' OR 1=1 --"),
      );
      expect(injection.tasks, isEmpty);
      expect(injection.totalCount, 5);
    },
  );

  test(
    'SQL searches Persian titles and distinguishes no matches from no tasks',
    () async {
      final empty = await list.getTasks(
        query: const TaskListQuery(title: 'کار'),
      );
      expect(empty.tasks, isEmpty);
      expect(empty.totalCount, 0);
      final id = await form.createTask(_draft(title: 'انجام کار روزانه'));
      expect(
        (await list.getTasks(
          query: const TaskListQuery(title: 'کار'),
        )).tasks.single.id,
        id,
      );
      final noMatches = await list.getTasks(
        query: const TaskListQuery(title: 'missing'),
      );
      expect(noMatches.tasks, isEmpty);
      expect(noMatches.totalCount, 1);
    },
  );

  test(
    'filtered rows keep deterministic creation order when timestamps tie',
    () async {
      final first = await form.createTask(_draft(title: 'Match first'));
      final second = await form.createTask(_draft(title: 'Match second'));
      await database.update('tasks', {'created_at': 10});
      expect(
        (await list.getTasks(
          query: const TaskListQuery(title: 'Match'),
        )).tasks.map((task) => task.id),
        [second, first],
      );
    },
  );

  test('activity sorts timestamps first and breaks ties with row id', () async {
    final id = await form.createTask(_draft());
    await list.toggleCompleted(id);
    await list.toggleCompleted(id);
    final events = await list.getActivity(id);
    await database.update('activity_events', {'occurred_at': 20});
    await database.update(
      'activity_events',
      {'occurred_at': 10},
      where: 'id = ?',
      whereArgs: [events.last.id],
    );

    expect((await list.getActivity(id)).map((event) => event.id), [
      events.last.id,
      events.first.id,
      events[1].id,
    ]);
  });
}

TaskFormData _draft({
  int? id,
  String title = 'Task',
  String? description,
  TaskFormPriority priority = TaskFormPriority.medium,
}) => TaskFormData(
  taskId: id,
  title: title,
  description: description,
  priority: priority,
);
