import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/admin/presentation/cubit/activity_overview/activity_overview_cubit.dart';

void main() {
  test('loads workspace activity and counts each type', () async {
    final repository = _ActivityRepository([
      _activity('one', WorkspaceActivityType.leadCreated),
      _activity('two', WorkspaceActivityType.leadCreated),
      _activity('three', WorkspaceActivityType.leadConverted),
      _activity('four', WorkspaceActivityType.callLogged),
    ]);
    final cubit = ActivityOverviewCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
    );
    addTearDown(cubit.close);

    await expectLater(
      cubit.stream.firstWhere(
        (state) => state.status == ActivityOverviewStatus.success,
      ),
      completes,
    );

    expect(cubit.state.activities, hasLength(4));
    expect(cubit.state.countOf(WorkspaceActivityType.leadCreated), 2);
    expect(cubit.state.countOf(WorkspaceActivityType.leadConverted), 1);
    expect(cubit.state.countOf(WorkspaceActivityType.callLogged), 1);
    expect(cubit.state.countOf(WorkspaceActivityType.taskCompleted), 0);
  });

  test('defaults to the last 7 days and re-queries when the period changes', () async {
    final repository = _ActivityRepository(const <WorkspaceActivity>[]);
    final cubit = ActivityOverviewCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
    );
    addTearDown(cubit.close);

    await cubit.stream.firstWhere(
      (state) => state.status == ActivityOverviewStatus.success,
    );

    expect(cubit.state.period, ActivityPeriod.week);
    expect(repository.sinceValues.single, isNotNull);

    await cubit.selectPeriod(ActivityPeriod.allTime);

    expect(repository.sinceValues.last, isNull);
    expect(cubit.state.period, ActivityPeriod.allTime);
  });

  test('passes representative and type filters to the repository', () async {
    final repository = _ActivityRepository(const <WorkspaceActivity>[]);
    final cubit = ActivityOverviewCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
    );
    addTearDown(cubit.close);

    await cubit.selectActor('rep-one');
    await cubit.selectType(WorkspaceActivityType.callLogged);

    expect(repository.actorValues.last, 'rep-one');
    expect(repository.typeValues.last, WorkspaceActivityType.callLogged);

    await cubit.selectActor(null);

    expect(repository.actorValues.last, isNull);
    expect(cubit.state.actorUserId, isNull);
  });

  test('reports a failure state when the stream errors', () async {
    final repository = _ActivityRepository(
      const <WorkspaceActivity>[],
      failure: const ActivityFailure(ActivityFailureCode.permissionDenied),
    );
    final cubit = ActivityOverviewCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
    );
    addTearDown(cubit.close);

    await cubit.stream.firstWhere(
      (state) => state.status == ActivityOverviewStatus.failure,
    );

    expect(
      cubit.state.failure,
      const ActivityFailure(ActivityFailureCode.permissionDenied),
    );
  });
}

WorkspaceActivity _activity(String id, WorkspaceActivityType type) =>
    WorkspaceActivity(
      id: id,
      workspaceId: 'workspace-one',
      type: type,
      contactId: 'contact-one',
      actorUserId: 'rep-one',
      createdAt: DateTime(2026, 7, 26),
      contactName: 'Acme Corp',
    );

final class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.activities, {this.failure});

  final List<WorkspaceActivity> activities;
  final ActivityFailure? failure;
  final List<DateTime?> sinceValues = [];
  final List<String?> actorValues = [];
  final List<WorkspaceActivityType?> typeValues = [];

  @override
  Stream<List<WorkspaceActivity>> watchWorkspaceActivity({
    required String workspaceId,
    DateTime? since,
    String? actorUserId,
    WorkspaceActivityType? type,
    int limit = 50,
  }) async* {
    sinceValues.add(since);
    actorValues.add(actorUserId);
    typeValues.add(type);

    if (failure != null) {
      throw failure!;
    }

    final controller = StreamController<List<WorkspaceActivity>>();
    controller.add(activities);

    await for (final value in controller.stream) {
      yield value;
    }
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
