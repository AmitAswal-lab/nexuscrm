import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';

abstract final class FirestoreTaskFailureMapper {
  static TaskFailure fromFirebase(FirebaseException error) {
    final code = switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => TaskFailureCode.permissionDenied,
      'not-found' => TaskFailureCode.notFound,
      'invalid-argument' || 'data-loss' => TaskFailureCode.invalidData,
      'unavailable' ||
      'deadline-exceeded' => TaskFailureCode.networkUnavailable,
      'aborted' || 'already-exists' => TaskFailureCode.conflict,
      _ => TaskFailureCode.unknown,
    };

    return TaskFailure(code);
  }
}
