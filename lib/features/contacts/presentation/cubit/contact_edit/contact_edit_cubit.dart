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
    Duration syncWaitThreshold = const Duration(seconds: 8),
  }) {
    return ContactEditCubit._(
      contactRepository,
      salesAssigneeRepository,
      workspaceId,
      contactId,
      actorUserId,
      requiresAssigneeDirectory,
      fixedOwnerId,
      syncWaitThreshold,
    );
  }

  ContactEditCubit._(
    this._contactRepository,
    this._salesAssigneeRepository,
    this._workspaceId,
    this._contactId,
    this._actorUserId,
    bool requiresAssigneeDirectory,
    this._fixedOwnerId,
    this._syncWaitThreshold,
  ) : _requiresAssigneeDirectory = requiresAssigneeDirectory,
      super(
        ContactEditState(
          assigneeStatus: requiresAssigneeDirectory
              ? ContactEditAssigneeStatus.loading
              : ContactEditAssigneeStatus.ready,
        ),
      ) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final SalesAssigneeRepository _salesAssigneeRepository;
  final String _workspaceId;
  final String _contactId;
  final String _actorUserId;
  final bool _requiresAssigneeDirectory;
  final String? _fixedOwnerId;
  final Duration _syncWaitThreshold;

  StreamSubscription<CrmContact?>? _contactSubscription;
  StreamSubscription<List<SalesAssignee>>? _assigneeSubscription;

  Future<void> load() async {
    await _contactSubscription?.cancel();
    await _assigneeSubscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(
      ContactEditState(
        assigneeStatus: _requiresAssigneeDirectory
            ? ContactEditAssigneeStatus.loading
            : ContactEditAssigneeStatus.ready,
      ),
    );

    _contactSubscription = _contactRepository
        .watchContact(workspaceId: _workspaceId, contactId: _contactId)
        .listen(_onContact, onError: _onContactError);

    if (_requiresAssigneeDirectory) {
      _assigneeSubscription = _salesAssigneeRepository
          .watchActiveSalesAssignees(workspaceId: _workspaceId)
          .listen(_onAssignees, onError: _onAssigneeError);
    }
  }

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
        assigneeStatus: ContactEditAssigneeStatus.loading,
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
    required LeadStage? leadStage,
  }) async {
    final contact = state.contact;

    if (contact == null ||
        state.status != ContactEditStatus.ready ||
        (state.submissionStatus == ContactEditSubmissionStatus.submitting ||
            state.submissionStatus ==
                ContactEditSubmissionStatus.waitingForSync)) {
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
      final update = switch (contact) {
        Lead() => _contactRepository.updateLead(
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
        ),
        ClientContact() => _contactRepository.updateClient(
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
        ),
      };
      final isStillWaiting = await Future.any<bool>([
        update.then((_) => false),
        Future<bool>.delayed(_syncWaitThreshold, () => true),
      ]);

      if (isStillWaiting && !isClosed) {
        emit(
          state.copyWith(
            submissionStatus: ContactEditSubmissionStatus.waitingForSync,
          ),
        );
      }

      await update;

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

    if (contact == null) {
      emit(
        state.copyWith(
          status: ContactEditStatus.notFound,
          clearContact: true,
          clearFailure: true,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: ContactEditStatus.ready,
          contact: contact,
          clearFailure: true,
        ),
      );
    }
  }

  void _onAssignees(List<SalesAssignee> assignees) {
    if (!isClosed) {
      emit(
        state.copyWith(
          assigneeStatus: ContactEditAssigneeStatus.ready,
          assignees: assignees,
          clearAssigneeFailure: true,
        ),
      );
    }
  }

  void _onContactError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        ContactEditState(
          status: ContactEditStatus.failure,
          assigneeStatus: state.assigneeStatus,
          failure: _typedFailure(error),
        ),
      );
    }
  }

  void _onAssigneeError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(
          assigneeStatus: ContactEditAssigneeStatus.failure,
          assigneeFailure: _typedFailure(error),
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
