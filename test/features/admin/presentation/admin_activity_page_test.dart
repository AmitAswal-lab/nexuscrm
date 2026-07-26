import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/presentation/cubit/activity_overview/activity_overview_cubit.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_activity_page.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

void main() {
  testWidgets('shows counts and readable activity lines', (tester) async {
    await _pump(tester, <WorkspaceActivity>[
      _activity(
        id: 'one',
        type: WorkspaceActivityType.leadCreated,
        contactName: 'Acme Corp',
      ),
      _activity(
        id: 'two',
        type: WorkspaceActivityType.taskCompleted,
        contactName: 'Acme Corp',
        detail: 'Send proposal',
      ),
    ]);

    expect(find.text('Team activity'), findsOneWidget);
    expect(find.text('New leads'), findsOneWidget);
    expect(find.text('Added lead Acme Corp'), findsOneWidget);
    expect(find.text('Completed Send proposal for Acme Corp'), findsOneWidget);
    expect(find.textContaining('Priya Sharma'), findsNWidgets(2));
  });

  testWidgets('names an unknown actor as a former representative', (
    tester,
  ) async {
    await _pump(tester, <WorkspaceActivity>[
      _activity(
        id: 'one',
        type: WorkspaceActivityType.leadConverted,
        contactName: 'Acme Corp',
        actorUserId: 'departed-user',
      ),
    ]);

    expect(find.textContaining('Former representative'), findsOneWidget);
    expect(find.text('Converted Acme Corp to a client'), findsOneWidget);
  });

  testWidgets('explains an empty period instead of showing nothing', (
    tester,
  ) async {
    await _pump(tester, const <WorkspaceActivity>[]);

    expect(find.textContaining('No activity in this period'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  List<WorkspaceActivity> activities,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (context) => ActivityOverviewCubit(
            activityRepository: _ActivityRepository(activities),
            workspaceId: 'workspace-one',
          ),
          child: const AdminActivityPage(
            workspaceId: 'workspace-one',
            teamRepository: _TeamRepository(),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

WorkspaceActivity _activity({
  required String id,
  required WorkspaceActivityType type,
  required String contactName,
  String actorUserId = 'rep-one',
  String? detail,
}) => WorkspaceActivity(
  id: id,
  workspaceId: 'workspace-one',
  type: type,
  contactId: 'contact-one',
  actorUserId: actorUserId,
  createdAt: DateTime(2026, 7, 26, 9, 30),
  contactName: contactName,
  detail: detail,
);

final class _TeamRepository implements AdminTeamRepository {
  const _TeamRepository();

  @override
  Stream<List<TeamMember>> watchTeam({required String workspaceId}) =>
      Stream.value(const <TeamMember>[
        TeamMember(
          userId: 'rep-one',
          displayName: 'Priya Sharma',
          email: 'priya@example.com',
          role: WorkspaceRole.salesRep,
          status: MembershipStatus.active,
        ),
      ]);
}

final class _ActivityRepository implements ActivityRepository {
  const _ActivityRepository(this.activities);

  final List<WorkspaceActivity> activities;

  @override
  Stream<List<WorkspaceActivity>> watchWorkspaceActivity({
    required String workspaceId,
    DateTime? since,
    String? actorUserId,
    WorkspaceActivityType? type,
    int limit = 50,
  }) => Stream.value(activities);

  @override
  Stream<List<CallNote>> watchCallNotes({
    required String workspaceId,
    required String contactId,
  }) => throw UnimplementedError();

  @override
  Future<String> createCallNote({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required CallNoteInput input,
  }) => throw UnimplementedError();
}
