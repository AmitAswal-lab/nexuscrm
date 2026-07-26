part of 'activity_overview_cubit.dart';

enum ActivityOverviewStatus { loading, success, failure }

enum ActivityPeriod { week, month, year, allTime }

extension ActivityPeriodRange on ActivityPeriod {
  String get label => switch (this) {
    ActivityPeriod.week => 'Last 7 days',
    ActivityPeriod.month => 'Last 30 days',
    ActivityPeriod.year => 'Last year',
    ActivityPeriod.allTime => 'All time',
  };

  DateTime? since(DateTime now) => switch (this) {
    ActivityPeriod.week => now.subtract(const Duration(days: 7)),
    ActivityPeriod.month => now.subtract(const Duration(days: 30)),
    ActivityPeriod.year => now.subtract(const Duration(days: 365)),
    ActivityPeriod.allTime => null,
  };
}

final class ActivityOverviewState extends Equatable {
  const ActivityOverviewState({
    this.status = ActivityOverviewStatus.loading,
    this.activities = const <WorkspaceActivity>[],
    this.period = ActivityPeriod.week,
    this.actorUserId,
    this.type,
    this.failure,
  });

  final ActivityOverviewStatus status;
  final List<WorkspaceActivity> activities;
  final ActivityPeriod period;
  final String? actorUserId;
  final WorkspaceActivityType? type;
  final ActivityFailure? failure;

  int countOf(WorkspaceActivityType type) =>
      activities.where((activity) => activity.type == type).length;

  ActivityOverviewState copyWith({
    ActivityOverviewStatus? status,
    List<WorkspaceActivity>? activities,
    ActivityPeriod? period,
    String? actorUserId,
    WorkspaceActivityType? type,
    ActivityFailure? failure,
    bool clearActor = false,
    bool clearType = false,
  }) => ActivityOverviewState(
    status: status ?? this.status,
    activities: activities ?? this.activities,
    period: period ?? this.period,
    actorUserId: clearActor ? actorUserId : (actorUserId ?? this.actorUserId),
    type: clearType ? type : (type ?? this.type),
    failure: failure,
  );

  @override
  List<Object?> get props => [
    status,
    activities,
    period,
    actorUserId,
    type,
    failure,
  ];
}
