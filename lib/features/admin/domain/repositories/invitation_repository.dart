import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';

abstract interface class InvitationRepository {
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  });
}
