import 'package:cloud_functions/cloud_functions.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';

final class FirebaseCallableInvitationRepository
    implements InvitationRepository {
  FirebaseCallableInvitationRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  }) => _callResult('createWorkspaceInvitation', <String, Object>{
    'workspaceId': workspaceId,
    'email': email,
  });

  @override
  Future<InvitationCreationResult> resendInvitation({
    required String workspaceId,
    required String invitationId,
  }) => _callResult('resendWorkspaceInvitation', <String, Object>{
    'workspaceId': workspaceId,
    'invitationId': invitationId,
  });

  @override
  Future<void> revokeInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    try {
      await _functions.httpsCallable('revokeWorkspaceInvitation').call(
        <String, Object>{
          'workspaceId': workspaceId,
          'invitationId': invitationId,
        },
      );
    } on FirebaseFunctionsException catch (error) {
      throw InvitationActionFailure(_failureCode(error.code));
    }
  }

  @override
  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
  }) => _callVoid('acceptWorkspaceInvitation', <String, Object>{
    'workspaceId': workspaceId,
    'invitationId': invitationId,
  });

  Future<InvitationCreationResult> _callResult(
    String functionName,
    Map<String, Object> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(functionName).call(data);
      return InvitationCreationResult.fromCallableData(result.data);
    } on FirebaseFunctionsException catch (error) {
      throw InvitationActionFailure(_failureCode(error.code));
    }
  }

  Future<void> _callVoid(String functionName, Map<String, Object> data) async {
    try {
      await _functions.httpsCallable(functionName).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw InvitationActionFailure(_failureCode(error.code));
    }
  }

  static InvitationActionFailureCode _failureCode(String code) =>
      switch (code) {
        'invalid-argument' => InvitationActionFailureCode.invalidInput,
        'already-exists' => InvitationActionFailureCode.duplicate,
        'permission-denied' ||
        'unauthenticated' => InvitationActionFailureCode.accessDenied,
        'resource-exhausted' => InvitationActionFailureCode.rateLimited,
        'failed-precondition' => InvitationActionFailureCode.expired,
        'unavailable' ||
        'deadline-exceeded' => InvitationActionFailureCode.unavailable,
        _ => InvitationActionFailureCode.unknown,
      };
}
