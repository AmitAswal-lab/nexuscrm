import 'package:equatable/equatable.dart';

enum WorkspaceRole { admin, salesRep }

enum MembershipStatus { invited, active, suspended, revoked }

final class WorkspaceMembership extends Equatable {
  const WorkspaceMembership({
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.status,
  });

  final String workspaceId;
  final String userId;
  final WorkspaceRole role;
  final MembershipStatus status;

  @override
  List<Object> get props => [workspaceId, userId, role, status];
}
