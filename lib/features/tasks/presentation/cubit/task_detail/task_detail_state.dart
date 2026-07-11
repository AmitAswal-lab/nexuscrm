part of 'task_detail_cubit.dart';

enum TaskDetailStatus { loading, ready, notFound, failure }

enum TaskActionStatus { idle, submitting, success, failure }

final class TaskDetailState extends Equatable {
  const TaskDetailState({
    this.status = TaskDetailStatus.loading,
    this.task,
    this.failure,
    this.actionStatus = TaskActionStatus.idle,
    this.actionFailure,
  });
  final TaskDetailStatus status;
  final CrmTask? task;
  final TaskFailure? failure;
  final TaskActionStatus actionStatus;
  final TaskFailure? actionFailure;
  TaskDetailState copyWith({
    TaskActionStatus? actionStatus,
    TaskFailure? actionFailure,
    bool clearActionFailure = false,
  }) => TaskDetailState(
    status: status,
    task: task,
    failure: failure,
    actionStatus: actionStatus ?? this.actionStatus,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
  );
  @override
  List<Object?> get props => [
    status,
    task,
    failure,
    actionStatus,
    actionFailure,
  ];
}
