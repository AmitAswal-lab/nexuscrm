import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

final class TeamMember extends Equatable {
  const TeamMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
  });

  final String userId;
  final String? displayName, email;
  final WorkspaceRole role;
  final MembershipStatus status;

  @override
  List<Object?> get props => [userId, displayName, email, role, status];
}
