import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';

part 'task_detail_state.dart';

final class TaskDetailCubit extends Cubit<TaskDetailState> {
  TaskDetailCubit({
    required this._taskRepository,
    required this._workspaceId,
    required this._taskId,
    required this._actorUserId,
  }) : super(const TaskDetailState()) {
    unawaited(load());
  }

  final TaskRepository _taskRepository;
  final String _workspaceId;
  final String _taskId;
  final String _actorUserId;
  StreamSubscription<CrmTask?>? _subscription;

  Future<void> load() async {
    await _subscription?.cancel();
    if (isClosed) return;
    emit(const TaskDetailState());
    _subscription = _taskRepository
        .watchTask(workspaceId: _workspaceId, taskId: _taskId)
        .listen(_onTask, onError: _onError);
  }

  Future<void> complete() => _runAction(_taskRepository.completeTask);

  Future<void> reopen() => _runAction(_taskRepository.reopenTask);

  Future<void> _runAction(
    Future<void> Function({
      required String workspaceId,
      required String taskId,
      required String actorUserId,
    })
    action,
  ) async {
    if (state.actionStatus == TaskActionStatus.submitting) return;
    emit(
      state.copyWith(
        actionStatus: TaskActionStatus.submitting,
        clearActionFailure: true,
      ),
    );
    try {
      await action(
        workspaceId: _workspaceId,
        taskId: _taskId,
        actorUserId: _actorUserId,
      );
      if (!isClosed) {
        emit(state.copyWith(actionStatus: TaskActionStatus.success));
      }
    } on TaskFailure catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            actionStatus: TaskActionStatus.failure,
            actionFailure: error,
          ),
        );
      }
    } on Object {
      if (!isClosed) {
        emit(
          state.copyWith(
            actionStatus: TaskActionStatus.failure,
            actionFailure: const TaskFailure(TaskFailureCode.unknown),
          ),
        );
      }
    }
  }

  void _onTask(CrmTask? task) {
    if (!isClosed) {
      emit(
        task == null
            ? const TaskDetailState(status: TaskDetailStatus.notFound)
            : TaskDetailState(status: TaskDetailStatus.ready, task: task),
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        TaskDetailState(
          status: TaskDetailStatus.failure,
          failure: error is TaskFailure
              ? error
              : const TaskFailure(TaskFailureCode.unknown),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
