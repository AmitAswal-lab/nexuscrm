import 'package:equatable/equatable.dart';

enum WorkspaceRole { admin, salesRep }

enum MembershipStatus { invited, active, suspended, revoked }

extension MembershipStatusTransitions on MembershipStatus {
  bool canTransitionTo(MembershipStatus next) {
    return switch (this) {
      MembershipStatus.invited =>
        next == MembershipStatus.active || next == MembershipStatus.revoked,
      MembershipStatus.active =>
        next == MembershipStatus.suspended || next == MembershipStatus.revoked,
      MembershipStatus.suspended =>
        next == MembershipStatus.active || next == MembershipStatus.revoked,
      MembershipStatus.revoked => false,
    };
  }
}

final class WorkspaceMembership extends Equatable {
  const WorkspaceMembership({
    required this.workspaceId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitationId,
  });

  final String workspaceId;
  final String userId;
  final WorkspaceRole role;
  final MembershipStatus status;
  final String? invitationId;

  @override
  List<Object?> get props => [workspaceId, userId, role, status, invitationId];
}
