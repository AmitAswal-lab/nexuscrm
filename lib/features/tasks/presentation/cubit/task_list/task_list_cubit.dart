import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

part 'task_list_state.dart';

final class TaskListCubit extends Cubit<TaskListState> {
  factory TaskListCubit({
    required TaskRepository taskRepository,
    required String workspaceId,
    required TaskAccessScope accessScope,
    DateTime? today,
  }) {
    return TaskListCubit._(
      taskRepository,
      workspaceId,
      accessScope,
      _dateKey(today ?? DateTime.now()),
    );
  }

  TaskListCubit._(
    this._taskRepository,
    this._workspaceId,
    this._accessScope,
    String today,
  ) : super(TaskListState(today: today)) {
    unawaited(load());
  }

  final TaskRepository _taskRepository;
  final String _workspaceId;
  final TaskAccessScope _accessScope;

  StreamSubscription<List<CrmTask>>? _subscription;

  Future<void> load() async {
    await _subscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(
      TaskListState(
        status: TaskListStatus.loading,
        tasks: state.tasks,
        view: state.view,
        today: state.today,
      ),
    );

    _subscription = _taskRepository
        .watchTasks(workspaceId: _workspaceId, accessScope: _accessScope)
        .listen(_onTasks, onError: _onError);
  }

  void selectView(TaskListView view) {
    if (view != state.view) {
      emit(state.copyWith(view: view));
    }
  }

  void _onTasks(List<CrmTask> tasks) {
    if (!isClosed) {
      emit(
        TaskListState(
          status: TaskListStatus.success,
          tasks: tasks,
          view: state.view,
          today: state.today,
        ),
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        TaskListState(
          status: TaskListStatus.failure,
          tasks: state.tasks,
          view: state.view,
          today: state.today,
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

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
