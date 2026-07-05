import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

part 'lead_form_state.dart';

final class LeadFormCubit extends Cubit<LeadFormState> {
  factory LeadFormCubit({
    required ContactRepository contactRepository,
    required SalesAssigneeRepository salesAssigneeRepository,
    required String workspaceId,
    required String actorUserId,
    required bool requiresAssigneeDirectory,
    String? fixedOwnerId,
  }) {
    return LeadFormCubit._(
      contactRepository,
      salesAssigneeRepository,
      workspaceId,
      actorUserId,
      requiresAssigneeDirectory,
      fixedOwnerId,
    );
  }

  LeadFormCubit._(
    this._contactRepository,
    this._salesAssigneeRepository,
    this._workspaceId,
    this._actorUserId,
    this._requiresAssigneeDirectory,
    this._fixedOwnerId,
  ) : super(
        LeadFormState(
          assigneeStatus: _requiresAssigneeDirectory
              ? AssigneeDirectoryStatus.loading
              : AssigneeDirectoryStatus.ready,
        ),
      ) {
    if (_requiresAssigneeDirectory) {
      unawaited(loadAssignees());
    }
  }

  final ContactRepository _contactRepository;
  final SalesAssigneeRepository _salesAssigneeRepository;
  final String _workspaceId;
  final String _actorUserId;
  final bool _requiresAssigneeDirectory;
  final String? _fixedOwnerId;

  StreamSubscription<List<SalesAssignee>>? _assigneeSubscription;

  Future<void> loadAssignees() async {
    if (!_requiresAssigneeDirectory) {
      return;
    }

    await _assigneeSubscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(
      state.copyWith(
        assigneeStatus: AssigneeDirectoryStatus.loading,
        clearAssigneeFailure: true,
      ),
    );

    _assigneeSubscription = _salesAssigneeRepository
        .watchActiveSalesAssignees(workspaceId: _workspaceId)
        .listen(_onAssignees, onError: _onAssigneeError);
  }

  Future<void> submit({
    required String fullName,
    required String? companyName,
    required String? email,
    required String? phone,
    required String? notes,
    required String? ownerId,
    required LeadStage stage,
  }) async {
    if (state.submissionStatus == LeadFormSubmissionStatus.submitting ||
        state.assigneeStatus != AssigneeDirectoryStatus.ready) {
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: LeadFormSubmissionStatus.submitting,
        clearSubmissionFailure: true,
      ),
    );

    try {
      await _contactRepository.createLead(
        workspaceId: _workspaceId,
        actorUserId: _actorUserId,
        input: LeadInput(
          fullName: fullName,
          companyName: companyName,
          email: email,
          phone: phone,
          notes: notes,
          ownerId: _fixedOwnerId ?? ownerId,
          stage: stage,
        ),
      );

      if (!isClosed) {
        emit(
          state.copyWith(submissionStatus: LeadFormSubmissionStatus.success),
        );
      }
    } on ContactFailure catch (failure) {
      _emitSubmissionFailure(failure);
    } on FormatException {
      _emitSubmissionFailure(
        const ContactFailure(ContactFailureCode.invalidData),
      );
    } on Object {
      _emitSubmissionFailure(const ContactFailure(ContactFailureCode.unknown));
    }
  }

  void _onAssignees(List<SalesAssignee> assignees) {
    if (!isClosed) {
      emit(
        state.copyWith(
          assigneeStatus: AssigneeDirectoryStatus.ready,
          assignees: assignees,
          clearAssigneeFailure: true,
        ),
      );
    }
  }

  void _onAssigneeError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(
          assigneeStatus: AssigneeDirectoryStatus.failure,
          assigneeFailure: _typedFailure(error),
        ),
      );
    }
  }

  void _emitSubmissionFailure(ContactFailure failure) {
    if (!isClosed) {
      emit(
        state.copyWith(
          submissionStatus: LeadFormSubmissionStatus.failure,
          submissionFailure: failure,
        ),
      );
    }
  }

  static ContactFailure _typedFailure(Object error) {
    return error is ContactFailure
        ? error
        : const ContactFailure(ContactFailureCode.unknown);
  }

  @override
  Future<void> close() async {
    await _assigneeSubscription?.cancel();
    return super.close();
  }
}
