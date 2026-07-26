import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';

abstract interface class InvitationRepository {
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  });

  Future<InvitationCreationResult> resendInvitation({
    required String workspaceId,
    required String invitationId,
  });

  Future<void> revokeInvitation({
    required String workspaceId,
    required String invitationId,
  });

  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
    required String displayName,
  });
}
