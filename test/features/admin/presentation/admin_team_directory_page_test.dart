import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/membership_management_repository.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_team_directory_page.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

void main() {
  testWidgets('shows representative names, roles, and access statuses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTeamDirectoryPage(
            workspaceId: 'workspace-one',
            teamRepository: _TeamRepository(<TeamMember>[
              const TeamMember(
                userId: 'admin-id',
                displayName: 'Amina Admin',
                email: 'amina@example.com',
                role: WorkspaceRole.admin,
                status: MembershipStatus.active,
              ),
              const TeamMember(
                userId: 'rep-id',
                displayName: 'Sam Representative',
                email: 'sam@example.com',
                role: WorkspaceRole.salesRep,
                status: MembershipStatus.suspended,
              ),
              const TeamMember(
                userId: 'pending-id',
                displayName: 'Pending Person',
                email: 'pending@example.com',
                role: WorkspaceRole.salesRep,
                status: MembershipStatus.invited,
              ),
            ]),
            invitationDirectoryRepository: _InvitationDirectoryRepository(
              <WorkspaceInvitation>[_invitation],
            ),
            invitationRepository: const _InvitationRepository(),
            membershipManagementRepository:
                const _MembershipManagementRepository(),
            onInvite: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final backButtonAlignment = tester.widget<Align>(
      find.ancestor(of: find.byTooltip('Back'), matching: find.byType(Align)),
    );
    expect(backButtonAlignment.alignment, Alignment.centerLeft);
    expect(find.text('Amina Admin'), findsOneWidget);
    expect(find.text('Administrator • Active'), findsOneWidget);
    expect(find.text('Sam Representative'), findsOneWidget);
    expect(find.text('Sales representative • Suspended'), findsOneWidget);
    expect(find.byTooltip('Manage representative'), findsOneWidget);
    expect(find.text('Pending Person'), findsNothing);
    expect(find.text('pending@example.com'), findsOneWidget);
    expect(find.textContaining('Email request failed'), findsOneWidget);
    expect(find.text('admin-id'), findsNothing);
    expect(find.text('rep-id'), findsNothing);
  });

  testWidgets('shows a safe error message when loading fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTeamDirectoryPage(
            workspaceId: 'workspace-one',
            teamRepository: _TeamRepository.error(),
            invitationDirectoryRepository: _InvitationDirectoryRepository(
              const <WorkspaceInvitation>[],
            ),
            invitationRepository: const _InvitationRepository(),
            membershipManagementRepository:
                const _MembershipManagementRepository(),
            onInvite: () {},
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Unable to load team members.'), findsOneWidget);
  });

  testWidgets('keeps a revoked representative busy until the team stream '
      'reports the new status', (tester) async {
    final teamRepository = _ControllableTeamRepository();
    addTearDown(teamRepository.controller.close);
    final management = _RecordingMembershipManagementRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTeamDirectoryPage(
            workspaceId: 'workspace-one',
            teamRepository: teamRepository,
            invitationDirectoryRepository: const _InvitationDirectoryRepository(
              <WorkspaceInvitation>[],
            ),
            invitationRepository: const _InvitationRepository(),
            membershipManagementRepository: management,
            onInvite: () {},
          ),
        ),
      ),
    );

    teamRepository.controller.add(const <TeamMember>[
      TeamMember(
        userId: 'rep-id',
        displayName: 'Sam Representative',
        email: 'sam@example.com',
        role: WorkspaceRole.salesRep,
        status: MembershipStatus.active,
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<MembershipStatus>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke access'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('permanent and cannot be undone'),
      findsOneWidget,
    );
    expect(find.textContaining('sign-in account is deleted'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Revoke access'));
    await tester.pump();
    await tester.pump();

    expect(management.calls, 1);
    expect(find.textContaining('Revoking…'), findsOneWidget);
    expect(find.byType(PopupMenuButton<MembershipStatus>), findsNothing);

    teamRepository.controller.add(const <TeamMember>[
      TeamMember(
        userId: 'rep-id',
        displayName: 'Sam Representative',
        email: 'sam@example.com',
        role: WorkspaceRole.salesRep,
        status: MembershipStatus.revoked,
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Revoked'), findsOneWidget);
    expect(find.textContaining('Revoking…'), findsNothing);
    expect(management.calls, 1);
  });
}

final _invitation = WorkspaceInvitation(
  id: 'invite-one',
  workspaceId: 'workspace-one',
  email: 'pending@example.com',
  role: 'sales_rep',
  status: InvitationStatus.pending,
  invitedByUserId: 'admin-id',
  createdAt: DateTime(2026, 7, 13),
  updatedAt: DateTime(2026, 7, 13),
  expiresAt: DateTime(2026, 7, 20),
  lastEmailRequestAt: null,
  emailRequestStatus: InvitationEmailRequestStatus.failed,
  resendRequestCount: 0,
  acceptedAt: null,
  acceptedByUserId: null,
  revokedAt: null,
  revokedByUserId: null,
);

final class _InvitationDirectoryRepository
    implements InvitationDirectoryRepository {
  const _InvitationDirectoryRepository(this.invitations);

  final List<WorkspaceInvitation> invitations;

  @override
  Stream<List<WorkspaceInvitation>> watchPendingInvitations({
    required String workspaceId,
  }) => Stream<List<WorkspaceInvitation>>.value(invitations);
}

final class _InvitationRepository implements InvitationRepository {
  const _InvitationRepository();

  @override
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeInvitation({
    required String workspaceId,
    required String invitationId,
  }) => throw UnimplementedError();

  @override
  Future<InvitationCreationResult> resendInvitation({
    required String workspaceId,
    required String invitationId,
  }) => throw UnimplementedError();

  @override
  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
    required String displayName,
  }) => throw UnimplementedError();
}

final class _MembershipManagementRepository
    implements MembershipManagementRepository {
  const _MembershipManagementRepository();

  @override
  Future<void> updateSalesRepresentativeStatus({
    required String workspaceId,
    required String userId,
    required MembershipStatus status,
  }) => throw UnimplementedError();
}

final class _RecordingMembershipManagementRepository
    implements MembershipManagementRepository {
  int calls = 0;

  @override
  Future<void> updateSalesRepresentativeStatus({
    required String workspaceId,
    required String userId,
    required MembershipStatus status,
  }) async {
    calls++;
  }
}

final class _TeamRepository implements AdminTeamRepository {
  _TeamRepository(this.members);
  _TeamRepository.error() : members = null;

  final List<TeamMember>? members;

  @override
  Stream<List<TeamMember>> watchTeam({required String workspaceId}) {
    if (members == null) return Stream<List<TeamMember>>.error(Exception());
    return Stream<List<TeamMember>>.value(members!);
  }
}

final class _ControllableTeamRepository implements AdminTeamRepository {
  final StreamController<List<TeamMember>> controller =
      StreamController<List<TeamMember>>.broadcast();

  @override
  Stream<List<TeamMember>> watchTeam({required String workspaceId}) =>
      controller.stream;
}
