import 'package:cloud_functions/cloud_functions.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/membership_management_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

final class FirebaseCallableMembershipManagementRepository
    implements MembershipManagementRepository {
  FirebaseCallableMembershipManagementRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<void> updateSalesRepresentativeStatus({
    required String workspaceId,
    required String userId,
    required MembershipStatus status,
  }) async {
    final action = switch (status) {
      MembershipStatus.suspended => 'suspend',
      MembershipStatus.active => 'reactivate',
      MembershipStatus.revoked => 'revoke',
      MembershipStatus.invited => throw ArgumentError.value(
        status,
        'status',
        'Invited status is not an administrator action.',
      ),
    };

    try {
      await _functions.httpsCallable('updateSalesRepresentativeStatus').call(
        <String, Object>{
          'workspaceId': workspaceId,
          'userId': userId,
          'action': action,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw InvitationActionFailure(_failureCode(error.code));
    }
  }

  static InvitationActionFailureCode _failureCode(String code) =>
      switch (code) {
        'invalid-argument' => InvitationActionFailureCode.invalidInput,
        'permission-denied' ||
        'unauthenticated' => InvitationActionFailureCode.accessDenied,
        'failed-precondition' => InvitationActionFailureCode.expired,
        'unavailable' ||
        'deadline-exceeded' => InvitationActionFailureCode.unavailable,
        _ => InvitationActionFailureCode.unknown,
      };
}
