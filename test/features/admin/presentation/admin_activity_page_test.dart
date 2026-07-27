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
  testWidgets('shows four counts at a glance without the full feed', (
    tester,
  ) async {
    await _pumpHome(tester, <WorkspaceActivity>[
      _activity(id: 'one', type: WorkspaceActivityType.leadCreated),
      _activity(id: 'two', type: WorkspaceActivityType.leadCreated),
      _activity(id: 'three', type: WorkspaceActivityType.callLogged),
    ]);

    expect(find.text('New leads'), findsOneWidget);
    expect(find.text('New clients'), findsOneWidget);
    expect(find.text('Calls logged'), findsOneWidget);
    expect(find.text('Tasks completed'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('View all activity'), findsOneWidget);
    expect(find.text('Added lead Acme Corp'), findsNothing);
  });

  testWidgets('opens the feed filtered to the count that was tapped', (
    tester,
  ) async {
    final repository = _ActivityRepository(<WorkspaceActivity>[
      _activity(id: 'one', type: WorkspaceActivityType.callLogged),
    ]);
    await _pumpHome(tester, repository.activities, repository: repository);

    await tester.tap(find.text('Calls logged'));
    await tester.pumpAndSettle();

    expect(repository.typeValues.last, WorkspaceActivityType.callLogged);
    expect(find.text('Logged a call with Acme Corp'), findsOneWidget);
    expect(find.textContaining('Priya Sharma'), findsOneWidget);
  });

  testWidgets('names an unknown actor as a former representative', (
    tester,
  ) async {
    await _pumpFeed(tester, <WorkspaceActivity>[
      _activity(
        id: 'one',
        type: WorkspaceActivityType.leadConverted,
        actorUserId: 'departed-user',
      ),
    ]);

    expect(find.textContaining('Former representative'), findsOneWidget);
    expect(find.text('Converted Acme Corp to a client'), findsOneWidget);
  });

  testWidgets('lists only active members as filter options', (tester) async {
    await _pumpFeed(tester, const <WorkspaceActivity>[]);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Departed Person'), findsNothing);
  });

  testWidgets('explains an empty period instead of showing nothing', (
    tester,
  ) async {
    await _pumpFeed(tester, const <WorkspaceActivity>[]);

    expect(find.textContaining('No activity in this period'), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  List<WorkspaceActivity> activities, {
  _ActivityRepository? repository,
}) async {
  final activityRepository = repository ?? _ActivityRepository(activities);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider(
          create: (context) => ActivityOverviewCubit(
            activityRepository: activityRepository,
            workspaceId: 'workspace-one',
          ),
          child: AdminActivityPage(
            workspaceId: 'workspace-one',
            teamRepository: const _TeamRepository(),
            activityRepository: activityRepository,
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _pumpFeed(
  WidgetTester tester,
  List<WorkspaceActivity> activities,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminActivityFeedPage(
        workspaceId: 'workspace-one',
        teamRepository: const _TeamRepository(),
        activityRepository: _ActivityRepository(activities),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

WorkspaceActivity _activity({
  required String id,
  required WorkspaceActivityType type,
  String actorUserId = 'rep-one',
  String? detail,
}) => WorkspaceActivity(
  id: id,
  workspaceId: 'workspace-one',
  type: type,
  contactId: 'contact-one',
  actorUserId: actorUserId,
  createdAt: DateTime(2026, 7, 26, 9, 30),
  contactName: 'Acme Corp',
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
        TeamMember(
          userId: 'revoked-user',
          displayName: 'Departed Person',
          email: 'departed@example.com',
          role: WorkspaceRole.salesRep,
          status: MembershipStatus.revoked,
        ),
      ]);
}

final class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.activities);

  final List<WorkspaceActivity> activities;
  final List<WorkspaceActivityType?> typeValues = [];

  @override
  Stream<List<WorkspaceActivity>> watchWorkspaceActivity({
    required String workspaceId,
    DateTime? since,
    String? actorUserId,
    WorkspaceActivityType? type,
    int limit = 50,
  }) {
    typeValues.add(type);

    return Stream.value(
      type == null
          ? activities
          : activities.where((it) => it.type == type).toList(growable: false),
    );
  }

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
