import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_list/task_list_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/pages/task_list_page.dart';

final class _MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late TaskRepository taskRepository;

  setUpAll(() {
    registerFallbackValue(const WorkspaceTaskAccess());
  });

  setUp(() {
    taskRepository = _MockTaskRepository();
  });

  testWidgets('renders today work and separates the planned views', (
    tester,
  ) async {
    when(
      () => taskRepository.watchTasks(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
      ),
    ).thenAnswer((_) => Stream.value(_tasks));

    await _pumpPage(tester, taskRepository, showAssignee: true);

    expect(find.text('Call Asha'), findsOneWidget);
    expect(find.text('Follow-up'), findsOneWidget);
    expect(find.text('Assigned to sales-user'), findsOneWidget);
    expect(find.text('Write proposal'), findsNothing);

    await tester.tap(find.text('Upcoming'));
    await tester.pump();
    expect(find.text('Write proposal'), findsOneWidget);
    expect(find.text('Call Asha'), findsNothing);

    await tester.tap(find.text('Overdue'));
    await tester.pump();
    expect(find.text('Send recap'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pump();
    expect(find.text('Log discovery call'), findsOneWidget);
    expect(find.text('Completed follow-up history'), findsOneWidget);
  });

  testWidgets('renders an honest empty state', (tester) async {
    when(
      () => taskRepository.watchTasks(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
      ),
    ).thenAnswer((_) => Stream.value(const <CrmTask>[]));

    await _pumpPage(tester, taskRepository, showAssignee: false);

    expect(find.text('No tasks due today.'), findsOneWidget);
    expect(
      find.text('Task creation will be added in the next workflow checkpoint.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a typed failure with an enabled retry action', (
    tester,
  ) async {
    final tasksController = StreamController<List<CrmTask>>.broadcast();
    addTearDown(tasksController.close);
    when(
      () => taskRepository.watchTasks(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
      ),
    ).thenAnswer((_) => tasksController.stream);

    await _pumpPage(tester, taskRepository, showAssignee: false);
    tasksController.addError(
      const TaskFailure(TaskFailureCode.networkUnavailable),
    );
    await tester.pump();

    expect(
      find.text('Tasks are unavailable. Check your connection and try again.'),
      findsOneWidget,
    );

    final retryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Try again'),
    );
    expect(retryButton.onPressed, isNotNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  TaskRepository taskRepository, {
  required bool showAssignee,
}) async {
  final cubit = TaskListCubit(
    taskRepository: taskRepository,
    workspaceId: 'workspace-one',
    accessScope: const WorkspaceTaskAccess(),
    today: DateTime(2026, 7, 11),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: TaskListPage(
          title: 'Workspace tasks',
          description: 'Tasks and follow-ups across this workspace.',
          showAssignee: showAssignee,
          onCreateTask: () {},
          onOpenTask: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

final _timestamp = DateTime.utc(2026);

final _tasks = <CrmTask>[
  _task(
    id: 'today',
    title: 'Call Asha',
    dueOn: '2026-07-11',
    kind: TaskKind.followUp,
  ),
  _task(id: 'upcoming', title: 'Write proposal', dueOn: '2026-07-12'),
  _task(id: 'overdue', title: 'Send recap', dueOn: '2026-07-10'),
  _task(
    id: 'completed',
    title: 'Log discovery call',
    dueOn: '2026-07-09',
    status: TaskStatus.completed,
    completionCount: 1,
    lastCompletedAt: _timestamp,
    lastCompletedByUserId: 'sales-user',
  ),
];

CrmTask _task({
  required String id,
  required String title,
  required String dueOn,
  TaskKind kind = TaskKind.task,
  TaskStatus status = TaskStatus.open,
  int completionCount = 0,
  DateTime? lastCompletedAt,
  String? lastCompletedByUserId,
}) {
  return CrmTask(
    id: id,
    workspaceId: 'workspace-one',
    contactId: 'contact-one',
    kind: kind,
    title: title,
    notes: null,
    assigneeId: 'sales-user',
    dueOn: dueOn,
    status: status,
    completionCount: completionCount,
    lastCompletedAt: lastCompletedAt,
    lastCompletedByUserId: lastCompletedByUserId,
    createdByUserId: 'sales-user',
    updatedByUserId: 'sales-user',
    createdAt: _timestamp,
    updatedAt: _timestamp,
  );
}
