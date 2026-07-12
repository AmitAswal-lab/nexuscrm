import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';

abstract final class FirestoreActivityFailureMapper {
  static ActivityFailure fromFirebase(FirebaseException error) {
    final code = switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => ActivityFailureCode.permissionDenied,
      'not-found' => ActivityFailureCode.notFound,
      'invalid-argument' || 'data-loss' => ActivityFailureCode.invalidData,
      'unavailable' ||
      'deadline-exceeded' => ActivityFailureCode.networkUnavailable,
      'aborted' || 'already-exists' => ActivityFailureCode.conflict,
      _ => ActivityFailureCode.unknown,
    };

    return ActivityFailure(code);
  }
}
