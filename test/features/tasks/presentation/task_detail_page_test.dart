import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_detail/task_detail_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/pages/task_detail_page.dart';

import '../../../helpers/empty_contact_repository.dart';

final class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late TaskRepository taskRepository;

  setUp(() {
    taskRepository = _MockTaskRepository();
  });

  testWidgets('offers cancellation only while a task is open', (tester) async {
    _stubTask(taskRepository, _task());

    await _pumpPage(tester, taskRepository);

    expect(find.text('Open'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Complete task'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel task'), findsOneWidget);
  });

  testWidgets('hides cancellation and offers reopen for a cancelled task', (
    tester,
  ) async {
    _stubTask(taskRepository, _task(status: TaskStatus.cancelled));

    await _pumpPage(tester, taskRepository);

    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Reopen task'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel task'), findsNothing);
  });

  testWidgets('keeps the task when the confirmation is dismissed', (
    tester,
  ) async {
    _stubTask(taskRepository, _task());

    await _pumpPage(tester, taskRepository);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keep task'));
    await tester.pumpAndSettle();

    verifyNever(
      () => taskRepository.cancelTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    );
    expect(find.text('Task detail'), findsOneWidget);
  });

  testWidgets('cancels after confirmation and returns to the task list', (
    tester,
  ) async {
    _stubTask(taskRepository, _task());
    when(
      () => taskRepository.cancelTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) async {});

    await _pumpPage(tester, taskRepository);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel task'));
    await tester.pumpAndSettle();

    verify(
      () => taskRepository.cancelTask(
        workspaceId: 'workspace-one',
        taskId: 'task-one',
        actorUserId: 'admin-user',
      ),
    ).called(1);
    expect(find.text('Task list'), findsOneWidget);
  });

  testWidgets('reports a cancellation failure without leaving the task', (
    tester,
  ) async {
    _stubTask(taskRepository, _task());
    when(
      () => taskRepository.cancelTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenThrow(Exception('denied'));

    await _pumpPage(tester, taskRepository);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel task'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel task'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to update this task. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Task detail'), findsOneWidget);
  });
}

void _stubTask(TaskRepository taskRepository, CrmTask task) {
  when(
    () => taskRepository.watchTask(
      workspaceId: any(named: 'workspaceId'),
      taskId: any(named: 'taskId'),
    ),
  ).thenAnswer((_) => Stream.value(task));
}

Future<void> _pumpPage(
  WidgetTester tester,
  TaskRepository taskRepository,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Task list'))),
      ),
      GoRoute(
        path: '/detail',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Task detail')),
          body: BlocProvider(
            create: (_) => TaskDetailCubit(
              taskRepository: taskRepository,
              workspaceId: 'workspace-one',
              taskId: 'task-one',
              actorUserId: 'admin-user',
            ),
            child: TaskDetailPage(
              onEdit: () {},
              workspaceId: 'workspace-one',
              contactRepository: const EmptyContactRepository(),
              assigneeRepository: const EmptySalesAssigneeRepository(),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  unawaited(router.push('/detail'));
  await tester.pumpAndSettle();
}

final _time = DateTime.utc(2026);

CrmTask _task({TaskStatus status = TaskStatus.open}) {
  return CrmTask(
    id: 'task-one',
    workspaceId: 'workspace-one',
    contactId: 'contact-one',
    kind: TaskKind.followUp,
    title: 'Call Asha',
    notes: null,
    assigneeId: 'sales-user',
    dueOn: '2026-07-11',
    status: status,
    completionCount: 0,
    lastCompletedAt: null,
    lastCompletedByUserId: null,
    createdByUserId: 'admin-user',
    updatedByUserId: 'admin-user',
    createdAt: _time,
    updatedAt: _time,
  );
}
