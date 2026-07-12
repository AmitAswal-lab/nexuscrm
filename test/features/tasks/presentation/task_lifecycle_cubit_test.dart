import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_detail/task_detail_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_form/task_form_cubit.dart';

final class _Tasks extends Mock implements TaskRepository {}

final class _Contacts extends Mock implements ContactRepository {}

final class _Assignees extends Mock implements SalesAssigneeRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OwnedContactAccess('user'));
    registerFallbackValue(
      const TaskInput(
        contactId: 'contact',
        kind: TaskKind.task,
        title: 'Task',
        notes: null,
        assigneeId: 'user',
        dueOn: '2026-07-11',
      ),
    );
  });

  test('loads a task and completes then reopens it', () async {
    final tasks = _Tasks();
    when(
      () => tasks.watchTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) => Stream.value(_task));
    when(
      () => tasks.completeTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => tasks.reopenTask(
        workspaceId: any(named: 'workspaceId'),
        taskId: any(named: 'taskId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) async {});
    final cubit = TaskDetailCubit(
      taskRepository: tasks,
      workspaceId: 'workspace',
      taskId: 'task',
      actorUserId: 'user',
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.task, _task);
    await cubit.complete();
    await cubit.reopen();
    verify(
      () => tasks.completeTask(
        workspaceId: 'workspace',
        taskId: 'task',
        actorUserId: 'user',
      ),
    ).called(1);
    verify(
      () => tasks.reopenTask(
        workspaceId: 'workspace',
        taskId: 'task',
        actorUserId: 'user',
      ),
    ).called(1);
  });

  test('creates a sales task with its fixed assignee', () async {
    final tasks = _Tasks();
    final contacts = _Contacts();
    final assignees = _Assignees();
    when(
      () => contacts.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => Stream.value(<CrmContact>[_lead]));
    when(
      () => tasks.createTask(
        workspaceId: any(named: 'workspaceId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async => 'new-task');
    final cubit = TaskFormCubit(
      taskRepository: tasks,
      contactRepository: contacts,
      salesAssigneeRepository: assignees,
      workspaceId: 'workspace',
      actorUserId: 'user',
      contactAccessScope: const OwnedContactAccess('user'),
      canAssign: false,
      fixedAssigneeId: 'user',
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await cubit.submit(
      const TaskInput(
        contactId: 'contact',
        kind: TaskKind.followUp,
        title: 'Call back',
        notes: null,
        assigneeId: 'user',
        dueOn: '2026-07-11',
      ),
    );
    verify(
      () => tasks.createTask(
        workspaceId: 'workspace',
        actorUserId: 'user',
        input: const TaskInput(
          contactId: 'contact',
          kind: TaskKind.followUp,
          title: 'Call back',
          notes: null,
          assigneeId: 'user',
          dueOn: '2026-07-11',
        ),
      ),
    ).called(1);
    expect(cubit.state.submissionStatus, TaskFormSubmissionStatus.success);
  });
}

final _time = DateTime.utc(2026);
final _task = CrmTask(
  id: 'task',
  workspaceId: 'workspace',
  contactId: 'contact',
  kind: TaskKind.task,
  title: 'Task',
  notes: null,
  assigneeId: 'user',
  dueOn: '2026-07-11',
  status: TaskStatus.open,
  completionCount: 0,
  lastCompletedAt: null,
  lastCompletedByUserId: null,
  createdByUserId: 'user',
  updatedByUserId: 'user',
  createdAt: _time,
  updatedAt: _time,
);
final _lead = Lead(
  id: 'contact',
  workspaceId: 'workspace',
  fullName: 'Asha',
  companyName: null,
  email: 'a@example.com',
  phone: null,
  notes: null,
  ownerId: 'user',
  stage: LeadStage.newLead,
  isArchived: false,
  createdByUserId: 'user',
  updatedByUserId: 'user',
  createdAt: _time,
  updatedAt: _time,
);
