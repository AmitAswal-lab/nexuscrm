import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
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
            repository: _TeamRepository(<TeamMember>[
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
            ]),
          ),
        ),
      ),
    );

    await tester.pump();

    final backButtonAlignment = tester.widget<Align>(
      find.ancestor(of: find.byTooltip('Back'), matching: find.byType(Align)),
    );
    expect(backButtonAlignment.alignment, Alignment.centerLeft);
    expect(find.text('Amina Admin'), findsOneWidget);
    expect(find.text('Administrator • Active'), findsOneWidget);
    expect(find.text('Sam Representative'), findsOneWidget);
    expect(find.text('Sales representative • Suspended'), findsOneWidget);
    expect(find.text('admin-id'), findsNothing);
    expect(find.text('rep-id'), findsNothing);
  });

  testWidgets('shows a safe error message when loading fails', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminTeamDirectoryPage(
            workspaceId: 'workspace-one',
            repository: _TeamRepository.error(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Unable to load the team directory.'), findsOneWidget);
  });
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
