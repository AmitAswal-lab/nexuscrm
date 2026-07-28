import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_activity_page.dart';

import '../../../helpers/empty_contact_repository.dart';

void main() {
  testWidgets('re-queries the feed when the activity filter changes', (
    tester,
  ) async {
    final repository = _RecordingActivityRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminActivityFeedPage(
          workspaceId: 'workspace-one',
          teamRepository: const EmptyAdminTeamRepository(),
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.typeValues.last, isNull);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calls').last);
    await tester.pumpAndSettle();

    expect(repository.typeValues.last, WorkspaceActivityType.callLogged);
  });
}

final class _RecordingActivityRepository implements ActivityRepository {
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
    return Stream.value(const <WorkspaceActivity>[]);
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
