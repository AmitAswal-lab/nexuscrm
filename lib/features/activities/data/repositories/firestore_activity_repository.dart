import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_activity_failure_mapper.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_call_note_mapper.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';

final class FirestoreActivityRepository implements ActivityRepository {
  FirestoreActivityRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CallNote>> watchCallNotes({
    required String workspaceId,
    required String contactId,
  }) async* {
    try {
      final query = _activities(_requiredIdentifier(workspaceId, 'workspaceId'))
          .where(
            'contactId',
            isEqualTo: _requiredIdentifier(contactId, 'contactId'),
          )
          .orderBy('createdAt', descending: true);

      await for (final snapshot in query.snapshots()) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        final notes = snapshot.docs
            .map(FirestoreCallNoteMapper.fromDocument)
            .toList(growable: false);
        yield List.unmodifiable(notes);
      }
    } on ActivityFailure {
      rethrow;
    } on FormatException {
      throw const ActivityFailure(ActivityFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreActivityFailureMapper.fromFirebase(error);
    }
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
      final data = FirestoreCallNoteMapper.createCallNoteData(
        workspaceId: workspaceId,
        contactId: contactId,
        actorUserId: actorUserId,
        input: input,
      );

      await reference.set(data);
      return reference.id;
    });
  }

  CollectionReference<Map<String, dynamic>> _activities(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('activities');
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
