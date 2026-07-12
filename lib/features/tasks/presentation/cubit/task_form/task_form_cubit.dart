import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';

part 'task_form_state.dart';

final class TaskFormCubit extends Cubit<TaskFormState> {
  TaskFormCubit({
    required this._taskRepository,
    required this._contactRepository,
    required this._salesAssigneeRepository,
    required this._workspaceId,
    required this._actorUserId,
    required this._contactAccessScope,
    required this._canAssign,
    this._fixedAssigneeId,
    String? taskId,
  }) : _taskId = taskId,
       super(TaskFormState(isEditing: taskId != null)) {
    _start();
  }
  final TaskRepository _taskRepository;
  final ContactRepository _contactRepository;
  final SalesAssigneeRepository _salesAssigneeRepository;
  final String _workspaceId, _actorUserId;
  final ContactAccessScope _contactAccessScope;
  final bool _canAssign;
  final String? _fixedAssigneeId, _taskId;
  StreamSubscription<List<CrmContact>>? _contacts;
  StreamSubscription<List<SalesAssignee>>? _assignees;
  StreamSubscription<CrmTask?>? _task;

  void _start() {
    _contacts = _contactRepository
        .watchContacts(
          workspaceId: _workspaceId,
          accessScope: _contactAccessScope,
        )
        .listen(
          (value) =>
              _emit(state.copyWith(contacts: value, contactsReady: true)),
          onError: (Object e, StackTrace s) =>
              _emit(state.copyWith(contactsFailure: _failure(e))),
        );
    if (_canAssign) {
      _assignees = _salesAssigneeRepository
          .watchActiveSalesAssignees(workspaceId: _workspaceId)
          .listen(
            (value) =>
                _emit(state.copyWith(assignees: value, assigneesReady: true)),
            onError: (Object e, StackTrace s) =>
                _emit(state.copyWith(assigneesFailure: _failure(e))),
          );
    } else {
      _emit(state.copyWith(assigneesReady: true));
    }
    if (_taskId != null) {
      _task = _taskRepository
          .watchTask(workspaceId: _workspaceId, taskId: _taskId)
          .listen(
            (value) => _emit(
              value == null
                  ? state.copyWith(taskStatus: TaskFormTaskStatus.notFound)
                  : state.copyWith(
                      taskStatus: TaskFormTaskStatus.ready,
                      task: value,
                    ),
            ),
            onError: (Object e, StackTrace s) => _emit(
              state.copyWith(
                taskStatus: TaskFormTaskStatus.failure,
                taskFailure: _failure(e),
              ),
            ),
          );
    } else {
      _emit(state.copyWith(taskStatus: TaskFormTaskStatus.ready));
    }
  }

  Future<void> submit(TaskInput input) async {
    if (!state.canSubmit) return;
    _emit(
      state.copyWith(
        submissionStatus: TaskFormSubmissionStatus.submitting,
        clearSubmissionFailure: true,
      ),
    );
    try {
      if (_taskId == null) {
        await _taskRepository.createTask(
          workspaceId: _workspaceId,
          actorUserId: _actorUserId,
          input: input,
        );
      } else {
        await _taskRepository.updateTask(
          workspaceId: _workspaceId,
          taskId: _taskId,
          actorUserId: _actorUserId,
          input: input,
        );
      }
      _emit(state.copyWith(submissionStatus: TaskFormSubmissionStatus.success));
    } on Object catch (e) {
      _emit(
        state.copyWith(
          submissionStatus: TaskFormSubmissionStatus.failure,
          submissionFailure: _failure(e),
        ),
      );
    }
  }

  String get fixedAssigneeId => _fixedAssigneeId ?? '';
  void _emit(TaskFormState value) {
    if (!isClosed) emit(value);
  }

  static TaskFailure _failure(Object error) =>
      error is TaskFailure ? error : const TaskFailure(TaskFailureCode.unknown);
  @override
  Future<void> close() async {
    await _contacts?.cancel();
    await _assignees?.cancel();
    await _task?.cancel();
    return super.close();
  }
}
