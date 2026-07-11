import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/tasks/data/mappers/firestore_task_mapper.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';

void main() {
  const input = TaskInput(
    contactId: ' contact-one ',
    kind: TaskKind.followUp,
    title: ' Follow up on proposal ',
    notes: ' Confirm next steps ',
    assigneeId: ' sales-user ',
    dueOn: '2026-07-10',
  );

  test('creates normalized open follow-up data', () {
    final data = FirestoreTaskMapper.createTaskData(
      workspaceId: ' workspace-one ',
      actorUserId: ' admin-user ',
      input: input,
    );

    expect(data['workspaceId'], 'workspace-one');
    expect(data['contactId'], 'contact-one');
    expect(data['kind'], 'follow_up');
    expect(data['title'], 'Follow up on proposal');
    expect(data['notes'], 'Confirm next steps');
    expect(data['assigneeId'], 'sales-user');
    expect(data['dueOn'], '2026-07-10');
    expect(data['status'], 'open');
    expect(data['completionCount'], 0);
    expect(data['lastCompletedAt'], isNull);
    expect(data['lastCompletedByUserId'], isNull);
    expect(data['createdByUserId'], 'admin-user');
    expect(data['updatedByUserId'], 'admin-user');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('omits the immutable contact ID from editable data', () {
    final data = FirestoreTaskMapper.updateTaskData(
      actorUserId: 'sales-user',
      input: input,
    );

    expect(data.containsKey('contactId'), isFalse);
    expect(data['kind'], 'follow_up');
    expect(data['updatedByUserId'], 'sales-user');
    expect(data['updatedAt'], isA<FieldValue>());
  });

  test('rejects invalid calendar dates and oversized task content', () {
    expect(
      () => FirestoreTaskMapper.createTaskData(
        workspaceId: 'workspace-one',
        actorUserId: 'admin-user',
        input: const TaskInput(
          contactId: 'contact-one',
          kind: TaskKind.task,
          title: 'Follow up',
          notes: null,
          assigneeId: 'sales-user',
          dueOn: '2026-02-29',
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => FirestoreTaskMapper.createTaskData(
        workspaceId: 'workspace-one',
        actorUserId: 'admin-user',
        input: TaskInput(
          contactId: 'contact-one',
          kind: TaskKind.task,
          title: 'x' * 121,
          notes: null,
          assigneeId: 'sales-user',
          dueOn: '2026-07-10',
        ),
      ),
      throwsFormatException,
    );
  });

  test('builds a counted completion update and preserves it on reopen', () {
    final completion = FirestoreTaskMapper.completeTaskData(
      actorUserId: 'sales-user',
      completionCount: 2,
    );
    final reopen = FirestoreTaskMapper.reopenTaskData(
      actorUserId: 'sales-user',
    );

    expect(completion['status'], 'completed');
    expect(completion['completionCount'], 3);
    expect(completion['lastCompletedAt'], isA<FieldValue>());
    expect(completion['lastCompletedByUserId'], 'sales-user');
    expect(reopen['status'], 'open');
    expect(reopen.containsKey('completionCount'), isFalse);
    expect(reopen.containsKey('lastCompletedAt'), isFalse);
  });
}
