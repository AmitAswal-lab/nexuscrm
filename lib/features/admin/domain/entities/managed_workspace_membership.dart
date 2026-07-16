import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

/// Backend-owned management metadata for a workspace membership.
final class ManagedWorkspaceMembership extends Equatable {
  const ManagedWorkspaceMembership({
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.status,
    required this.invitationId,
    required this.createdAt,
    required this.createdByUserId,
    required this.updatedAt,
    required this.updatedByUserId,
    required this.statusChangedAt,
    required this.statusChangedByUserId,
  });

  final String workspaceId, userId, createdByUserId, updatedByUserId;
  final String? invitationId, statusChangedByUserId;
  final WorkspaceRole role;
  final MembershipStatus status;
  final DateTime createdAt, updatedAt;
  final DateTime? statusChangedAt;

  @override
  List<Object?> get props => [
    workspaceId,
    userId,
    role,
    status,
    invitationId,
    createdAt,
    createdByUserId,
    updatedAt,
    updatedByUserId,
    statusChangedAt,
    statusChangedByUserId,
  ];
}
