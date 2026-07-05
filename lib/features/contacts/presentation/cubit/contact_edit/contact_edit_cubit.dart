import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

part 'contact_edit_state.dart';

final class ContactEditCubit extends Cubit<ContactEditState> {
  factory ContactEditCubit({
    required ContactRepository contactRepository,
    required SalesAssigneeRepository salesAssigneeRepository,
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required bool requiresAssigneeDirectory,
    String? fixedOwnerId,
  }) {
    return ContactEditCubit._(
      contactRepository,
      salesAssigneeRepository,
      workspaceId,
      contactId,
      actorUserId,
      requiresAssigneeDirectory,
      fixedOwnerId,
    );
  }

  ContactEditCubit._(
    this._contactRepository,
    this._salesAssigneeRepository,
    this._workspaceId,
    this._contactId,
    this._actorUserId,
    this._requiresAssigneeDirectory,
    this._fixedOwnerId,
  ) : super(const ContactEditState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final SalesAssigneeRepository _salesAssigneeRepository;
  final String _workspaceId;
  final String _contactId;
  final String _actorUserId;
  final bool _requiresAssigneeDirectory;
  final String? _fixedOwnerId;

  StreamSubscription<CrmContact?>? _contactSubscription;
  StreamSubscription<List<SalesAssignee>>? _assigneeSubscription;
  CrmContact? _contact;
  List<SalesAssignee> _assignees = const [];
  bool _contactResolved = false;
  bool _assigneesResolved = false;

  Future<void> load() async {
    await _contactSubscription?.cancel();
    await _assigneeSubscription?.cancel();

    if (isClosed) {
      return;
    }

    _contact = null;
    _assignees = const [];
    _contactResolved = false;
    _assigneesResolved = !_requiresAssigneeDirectory;
    emit(const ContactEditState());

    _contactSubscription = _contactRepository
        .watchContact(workspaceId: _workspaceId, contactId: _contactId)
        .listen(_onContact, onError: _onLoadError);

    if (_requiresAssigneeDirectory) {
      _assigneeSubscription = _salesAssigneeRepository
          .watchActiveSalesAssignees(workspaceId: _workspaceId)
          .listen(_onAssignees, onError: _onLoadError);
    }
  }

  Future<void> submit({
    required String fullName,
    required String? companyName,
    required String? email,
    required String? phone,
    required String? notes,
    required String? ownerId,
    required LeadStage? leadStage,
  }) async {
    final contact = state.contact;

    if (contact == null ||
        state.status != ContactEditStatus.ready ||
        state.submissionStatus == ContactEditSubmissionStatus.submitting) {
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: ContactEditSubmissionStatus.submitting,
        clearSubmissionFailure: true,
      ),
    );

    final resolvedOwnerId = _fixedOwnerId ?? ownerId;

    try {
      switch (contact) {
        case Lead():
          await _contactRepository.updateLead(
            workspaceId: _workspaceId,
            contactId: _contactId,
            actorUserId: _actorUserId,
            input: LeadInput(
              fullName: fullName,
              companyName: companyName,
              email: email,
              phone: phone,
              notes: notes,
              ownerId: resolvedOwnerId,
              stage: leadStage ?? contact.stage,
            ),
          );
        case ClientContact():
          await _contactRepository.updateClient(
            workspaceId: _workspaceId,
            contactId: _contactId,
            actorUserId: _actorUserId,
            input: ClientInput(
              fullName: fullName,
              companyName: companyName,
              email: email,
              phone: phone,
              notes: notes,
              ownerId: resolvedOwnerId,
            ),
          );
      }

      if (!isClosed) {
        emit(
          state.copyWith(submissionStatus: ContactEditSubmissionStatus.success),
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

  void _onContact(CrmContact? contact) {
    if (isClosed) {
      return;
    }

    _contactResolved = true;
    _contact = contact;

    if (contact == null) {
      emit(const ContactEditState(status: ContactEditStatus.notFound));
    } else {
      _emitReadyIfResolved();
    }
  }

  void _onAssignees(List<SalesAssignee> assignees) {
    if (!isClosed) {
      _assigneesResolved = true;
      _assignees = assignees;
      _emitReadyIfResolved();
    }
  }

  void _emitReadyIfResolved() {
    if (_contactResolved && _assigneesResolved && _contact != null) {
      emit(
        ContactEditState(
          status: ContactEditStatus.ready,
          contact: _contact,
          assignees: _assignees,
          submissionStatus: state.submissionStatus,
          submissionFailure: state.submissionFailure,
        ),
      );
    }
  }

  void _onLoadError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        ContactEditState(
          status: ContactEditStatus.failure,
          failure: _typedFailure(error),
        ),
      );
    }
  }

  void _emitSubmissionFailure(ContactFailure failure) {
    if (!isClosed) {
      emit(
        state.copyWith(
          submissionStatus: ContactEditSubmissionStatus.failure,
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
    await _contactSubscription?.cancel();
    await _assigneeSubscription?.cancel();
    return super.close();
  }
}
