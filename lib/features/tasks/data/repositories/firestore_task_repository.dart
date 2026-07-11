import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/tasks/data/mappers/firestore_task_failure_mapper.dart';
import 'package:nexuscrm/features/tasks/data/mappers/firestore_task_mapper.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

final class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CrmTask>> watchTasks({
    required String workspaceId,
    required TaskAccessScope accessScope,
  }) async* {
    try {
      final normalizedWorkspaceId = _requiredIdentifier(
        workspaceId,
        'workspaceId',
      );
      Query<Map<String, dynamic>> query = _tasks(normalizedWorkspaceId);

      query = switch (accessScope) {
        WorkspaceTaskAccess() => query,
        AssignedTaskAccess(:final assigneeId) => query.where(
          'assigneeId',
          isEqualTo: _requiredIdentifier(assigneeId, 'assigneeId'),
        ),
      };

      query = query.orderBy('dueOn');

      await for (final snapshot in query.snapshots()) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        final tasks =
            snapshot.docs.map(FirestoreTaskMapper.fromDocument).toList()
              ..sort(_compareTasks);

        yield List.unmodifiable(tasks);
      }
    } on TaskFailure {
      rethrow;
    } on FormatException {
      throw const TaskFailure(TaskFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreTaskFailureMapper.fromFirebase(error);
    }
  }

  @override
  Stream<CrmTask?> watchTask({
    required String workspaceId,
    required String taskId,
  }) async* {
    try {
      final reference = _taskReference(
        workspaceId: workspaceId,
        taskId: taskId,
      );

      await for (final snapshot in reference.snapshots()) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        yield snapshot.exists
            ? FirestoreTaskMapper.fromDocument(snapshot)
            : null;
      }
    } on TaskFailure {
      rethrow;
    } on FormatException {
      throw const TaskFailure(TaskFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreTaskFailureMapper.fromFirebase(error);
    }
  }

  @override
  Stream<List<CrmTask>> watchContactTasks({
    required String workspaceId,
    required String contactId,
    required TaskAccessScope accessScope,
  }) async* {
    try {
      Query<Map<String, dynamic>> query =
          _tasks(_requiredIdentifier(workspaceId, 'workspaceId')).where(
            'contactId',
            isEqualTo: _requiredIdentifier(contactId, 'contactId'),
          );
      query = switch (accessScope) {
        WorkspaceTaskAccess() => query,
        AssignedTaskAccess(:final assigneeId) => query.where(
          'assigneeId',
          isEqualTo: _requiredIdentifier(assigneeId, 'assigneeId'),
        ),
      };
      await for (final snapshot in query.snapshots()) {
        if (!snapshot.metadata.hasPendingWrites) {
          final tasks =
              snapshot.docs.map(FirestoreTaskMapper.fromDocument).toList()
                ..sort(_compareTasks);
          yield List.unmodifiable(tasks);
        }
      }
    } on TaskFailure {
      rethrow;
    } on FormatException {
      throw const TaskFailure(TaskFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreTaskFailureMapper.fromFirebase(error);
    }
  }

  @override
  Future<String> createTask({
    required String workspaceId,
    required String actorUserId,
    required TaskInput input,
  }) {
    return _execute(() async {
      final reference = _tasks(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      ).doc();
      final data = FirestoreTaskMapper.createTaskData(
        workspaceId: workspaceId,
        actorUserId: actorUserId,
        input: input,
      );

      await reference.set(data);
      return reference.id;
    });
  }

  @override
  Future<void> updateTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
    required TaskInput input,
  }) {
    return _execute(() async {
      final reference = _taskReference(
        workspaceId: workspaceId,
        taskId: taskId,
      );
      final data = FirestoreTaskMapper.updateTaskData(
        actorUserId: actorUserId,
        input: input,
      );

      await _firestore.runTransaction((transaction) async {
        final task = _existingTask(await transaction.get(reference));

        if (task.contactId != input.contactId.trim()) {
          throw const TaskFailure(TaskFailureCode.conflict);
        }

        transaction.update(reference, data);
      });
    });
  }

  @override
  Future<void> completeTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  }) {
    return _execute(() async {
      final reference = _taskReference(
        workspaceId: workspaceId,
        taskId: taskId,
      );

      await _firestore.runTransaction((transaction) async {
        final task = _existingTask(await transaction.get(reference));

        if (task.isCompleted) {
          throw const TaskFailure(TaskFailureCode.conflict);
        }

        transaction.update(
          reference,
          FirestoreTaskMapper.completeTaskData(
            actorUserId: actorUserId,
            completionCount: task.completionCount,
          ),
        );
      });
    });
  }

  @override
  Future<void> reopenTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  }) {
    return _execute(() async {
      final reference = _taskReference(
        workspaceId: workspaceId,
        taskId: taskId,
      );

      await _firestore.runTransaction((transaction) async {
        final task = _existingTask(await transaction.get(reference));

        if (!task.isCompleted) {
          throw const TaskFailure(TaskFailureCode.conflict);
        }

        transaction.update(
          reference,
          FirestoreTaskMapper.reopenTaskData(actorUserId: actorUserId),
        );
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _tasks(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('tasks');
  }

  DocumentReference<Map<String, dynamic>> _taskReference({
    required String workspaceId,
    required String taskId,
  }) {
    return _tasks(
      _requiredIdentifier(workspaceId, 'workspaceId'),
    ).doc(_requiredIdentifier(taskId, 'taskId'));
  }

  static CrmTask _existingTask(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      throw const TaskFailure(TaskFailureCode.notFound);
    }

    return FirestoreTaskMapper.fromDocument(snapshot);
  }

  static String _requiredIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid task identifier: $field.');
    }

    return normalized;
  }

  static int _compareTasks(CrmTask first, CrmTask second) {
    final dueDateComparison = first.dueOn.compareTo(second.dueOn);

    if (dueDateComparison != 0) {
      return dueDateComparison;
    }

    final updatedComparison = second.updatedAt.compareTo(first.updatedAt);
    return updatedComparison != 0
        ? updatedComparison
        : first.id.compareTo(second.id);
  }

  static Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on TaskFailure {
      rethrow;
    } on FormatException {
      throw const TaskFailure(TaskFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreTaskFailureMapper.fromFirebase(error);
    }
  }
}
