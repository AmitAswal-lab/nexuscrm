import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_activity_failure_mapper.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_call_note_mapper.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_workspace_activity_mapper.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/tasks/data/mappers/firestore_task_mapper.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';

final class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CallNote>> watchCallNotes({
    required String workspaceId,
    required String contactId,
  }) {
    return _watch(() {
      return _activities(_requiredIdentifier(workspaceId, 'workspaceId'))
          .where(
            'contactId',
            isEqualTo: _requiredIdentifier(contactId, 'contactId'),
          )
          .orderBy('createdAt', descending: true)
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_callNotes);
    }, _callNoteError);
  }

  @override
  Stream<List<WorkspaceActivity>> watchWorkspaceActivity({
    required String workspaceId,
    DateTime? since,
    String? actorUserId,
    WorkspaceActivityType? type,
    int limit = 50,
  }) {
    return _watch(() {
      Query<Map<String, dynamic>> query = _activities(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      );

      if (actorUserId != null) {
        query = query.where(
          'actorUserId',
          isEqualTo: _requiredIdentifier(actorUserId, 'actorUserId'),
        );
      }

      if (type != null) {
        query = query.where(
          'type',
          isEqualTo: FirestoreWorkspaceActivityMapper.typeName(type),
        );
      }

      if (since != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(since),
        );
      }

      return query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_workspaceActivities);
    }, _activityError);
  }

  @override
  Future<String> createCallNote({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required CallNoteInput input,
  }) {
    return _execute(() async {
      final reference = _activities(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      ).doc();
      final followUp = input.followUp;
      final taskReference = followUp == null
          ? null
          : _tasks(_requiredIdentifier(workspaceId, 'workspaceId')).doc();
      final data = FirestoreCallNoteMapper.createCallNoteData(
        workspaceId: workspaceId,
        contactId: contactId,
        actorUserId: actorUserId,
        input: input,
        nextTaskId: taskReference?.id,
      );

      if (followUp == null) {
        await reference.set(data);
      } else {
        final batch = _firestore.batch();
        batch.set(reference, data);
        batch.set(
          taskReference!,
          FirestoreTaskMapper.createTaskData(
            workspaceId: workspaceId,
            actorUserId: actorUserId,
            input: TaskInput(
              contactId: contactId,
              kind: TaskKind.followUp,
              title: followUp.title,
              notes: null,
              assigneeId: followUp.assigneeId,
              dueOn: followUp.dueOn,
            ),
          ),
        );
        await batch.commit();
      }
      return reference.id;
    });
  }

  CollectionReference<Map<String, dynamic>> _activities(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('activities');
  }

  CollectionReference<Map<String, dynamic>> _tasks(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('tasks');
  }

  static List<CallNote> _callNotes(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final notes = snapshot.docs
        .where(
          (document) => FirestoreWorkspaceActivityMapper.isType(
            document,
            FirestoreWorkspaceActivityMapper.callNoteType,
          ),
        )
        .map(FirestoreCallNoteMapper.fromDocument)
        .toList(growable: false);

    return List.unmodifiable(notes);
  }

  static List<WorkspaceActivity> _workspaceActivities(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final activities = <WorkspaceActivity>[];

    for (final document in snapshot.docs) {
      try {
        activities.add(FirestoreWorkspaceActivityMapper.fromDocument(document));
      } on FormatException {
        continue;
      }
    }

    return List.unmodifiable(activities);
  }

  static Stream<T> _watch<T>(
    Stream<T> Function() build,
    Object Function(Object) mapError,
  ) {
    try {
      return build().handleError((Object error) => throw mapError(error));
    } on Object catch (error) {
      return Stream.error(mapError(error));
    }
  }

  static Object _activityError(Object error) {
    if (error is ActivityFailure) {
      return error;
    }

    return error is FirebaseException
        ? FirestoreActivityFailureMapper.fromFirebase(error)
        : error;
  }

  static Object _callNoteError(Object error) {
    return error is FormatException
        ? const ActivityFailure(ActivityFailureCode.invalidData)
        : _activityError(error);
  }

  static String _requiredIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid activity identifier: $field.');
    }

    return normalized;
  }

  static Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ActivityFailure {
      rethrow;
    } on FormatException {
      throw const ActivityFailure(ActivityFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreActivityFailureMapper.fromFirebase(error);
    }
  }
}
