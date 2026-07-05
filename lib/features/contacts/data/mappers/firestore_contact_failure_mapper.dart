import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';

abstract final class FirestoreContactFailureMapper {
  static ContactFailure fromFirebase(FirebaseException error) {
    final code = switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => ContactFailureCode.permissionDenied,
      'not-found' => ContactFailureCode.notFound,
      'invalid-argument' || 'data-loss' => ContactFailureCode.invalidData,
      'unavailable' ||
      'deadline-exceeded' => ContactFailureCode.networkUnavailable,
      'aborted' || 'already-exists' => ContactFailureCode.conflict,
      _ => ContactFailureCode.unknown,
    };

    return ContactFailure(code);
  }
}
