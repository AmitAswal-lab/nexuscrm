import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/authentication/data/mappers/firestore_membership_mapper.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';

final class FirestoreMembershipRepository implements MembershipRepository {
  FirestoreMembershipRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({
    required String userId,
  }) async* {
    if (userId.trim().isEmpty) {
      throw const AuthenticationFailure(AuthenticationFailureCode.invalidData);
    }

    try {
      final snapshots = _firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .snapshots();

      await for (final snapshot in snapshots) {
        final memberships =
            snapshot.docs.map(FirestoreMembershipMapper.fromDocument).toList()
              ..sort(
                (first, second) =>
                    first.workspaceId.compareTo(second.workspaceId),
              );

        yield List.unmodifiable(memberships);
      }
    } on FormatException {
      throw const AuthenticationFailure(AuthenticationFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw _mapFailure(error);
    }
  }

  static AuthenticationFailure _mapFailure(FirebaseException error) {
    final code = switch (error.code) {
      'permission-denied' ||
      'unauthenticated' => AuthenticationFailureCode.permissionDenied,
      'unavailable' ||
      'deadline-exceeded' => AuthenticationFailureCode.networkUnavailable,
      _ => AuthenticationFailureCode.unknown,
    };

    return AuthenticationFailure(code);
  }
}
