import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';

part 'activity_overview_state.dart';

final class ActivityOverviewCubit extends Cubit<ActivityOverviewState> {
  factory ActivityOverviewCubit({
    required ActivityRepository activityRepository,
    required String workspaceId,
  }) => ActivityOverviewCubit._(activityRepository, workspaceId);

  ActivityOverviewCubit._(this._activityRepository, this._workspaceId)
    : super(const ActivityOverviewState()) {
    unawaited(load());
  }

  final ActivityRepository _activityRepository;
  final String _workspaceId;

  StreamSubscription<List<WorkspaceActivity>>? _subscription;

  Future<void> load() async {
    await _subscription?.cancel();

    if (isClosed) return;

    emit(state.copyWith(status: ActivityOverviewStatus.loading));

    _subscription = _activityRepository
        .watchWorkspaceActivity(
          workspaceId: _workspaceId,
          since: state.period.since(DateTime.now()),
          actorUserId: state.actorUserId,
          type: state.type,
          limit: 100,
        )
        .listen(_onActivities, onError: _onError);
  }

  Future<void> selectPeriod(ActivityPeriod period) async {
    if (period == state.period) return;
    emit(state.copyWith(period: period));
    await load();
  }

  Future<void> selectActor(String? actorUserId) async {
    if (actorUserId == state.actorUserId) return;
    emit(state.copyWith(actorUserId: actorUserId, clearActor: true));
    await load();
  }

  Future<void> selectType(WorkspaceActivityType? type) async {
    if (type == state.type) return;
    emit(state.copyWith(type: type, clearType: true));
    await load();
  }

  void _onActivities(List<WorkspaceActivity> activities) {
    if (isClosed) return;

    emit(
      state.copyWith(
        status: ActivityOverviewStatus.success,
        activities: activities,
      ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (isClosed) return;

    emit(
      state.copyWith(
        status: ActivityOverviewStatus.failure,
        failure: error is ActivityFailure
            ? error
            : const ActivityFailure(ActivityFailureCode.unknown),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
