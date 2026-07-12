import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

part 'sales_dashboard_state.dart';

final class SalesDashboardCubit extends Cubit<SalesDashboardState> {
  factory SalesDashboardCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required String ownerId,
    TaskRepository? taskRepository,
  }) {
    return SalesDashboardCubit._(
      contactRepository,
      workspaceId,
      ownerId,
      taskRepository,
    );
  }

  SalesDashboardCubit._(
    this._contactRepository,
    this._workspaceId,
    this._ownerId,
    this._taskRepository,
  ) : super(const SalesDashboardState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final String _ownerId;
  final TaskRepository? _taskRepository;

  StreamSubscription<List<CrmContact>>? _subscription;
  StreamSubscription<List<CrmTask>>? _taskSubscription;

  Future<void> load() async {
    await _subscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(const SalesDashboardState());
    _subscription = _contactRepository
        .watchContacts(
          workspaceId: _workspaceId,
          accessScope: OwnedContactAccess(_ownerId),
        )
        .listen(_onContacts, onError: _onError);
    final taskRepository = _taskRepository;
    if (taskRepository != null) {
      _taskSubscription = taskRepository
          .watchTasks(
            workspaceId: _workspaceId,
            accessScope: AssignedTaskAccess(_ownerId),
          )
          .listen((tasks) {
            if (!isClosed) emit(state.copyWith(tasks: tasks, taskReady: true));
          });
    }
  }

  void _onContacts(List<CrmContact> contacts) {
    if (!isClosed) {
      emit(
        SalesDashboardState(
          status: SalesDashboardStatus.success,
          contacts: contacts,
          tasks: state.tasks,
          taskReady: state.taskReady,
        ),
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        SalesDashboardState(
          status: SalesDashboardStatus.failure,
          failure: error is ContactFailure
              ? error
              : const ContactFailure(ContactFailureCode.unknown),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _taskSubscription?.cancel();
    return super.close();
  }
}
