import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';

abstract interface class InvitationDirectoryRepository {
  Stream<List<WorkspaceInvitation>> watchPendingInvitations({
    required String workspaceId,
  });
}
