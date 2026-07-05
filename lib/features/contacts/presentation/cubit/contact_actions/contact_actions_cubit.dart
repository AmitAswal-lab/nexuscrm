import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';

part 'contact_actions_state.dart';

final class ContactActionsCubit extends Cubit<ContactActionsState> {
  factory ContactActionsCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    return ContactActionsCubit._(
      contactRepository,
      workspaceId,
      contactId,
      actorUserId,
    );
  }

  ContactActionsCubit._(
    this._contactRepository,
    this._workspaceId,
    this._contactId,
    this._actorUserId,
  ) : super(const ContactActionsState());

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final String _contactId;
  final String _actorUserId;

  Future<void> convertLead() async {
    if (state.isBusy) {
      return;
    }

    emit(const ContactActionsState(status: ContactActionStatus.converting));

    try {
      await _contactRepository.convertLead(
        workspaceId: _workspaceId,
        contactId: _contactId,
        actorUserId: _actorUserId,
      );

      if (!isClosed) {
        emit(
          const ContactActionsState(
            status: ContactActionStatus.conversionSuccess,
          ),
        );
      }
    } on ContactFailure catch (failure) {
      _emitFailure(failure);
    } on Object {
      _emitFailure(const ContactFailure(ContactFailureCode.unknown));
    }
  }

  Future<void> archiveContact() async {
    if (state.isBusy) {
      return;
    }

    emit(const ContactActionsState(status: ContactActionStatus.archiving));

    try {
      await _contactRepository.archiveContact(
        workspaceId: _workspaceId,
        contactId: _contactId,
        actorUserId: _actorUserId,
      );

      if (!isClosed) {
        emit(
          const ContactActionsState(status: ContactActionStatus.archiveSuccess),
        );
      }
    } on ContactFailure catch (failure) {
      _emitFailure(failure);
    } on Object {
      _emitFailure(const ContactFailure(ContactFailureCode.unknown));
    }
  }

  void _emitFailure(ContactFailure failure) {
    if (!isClosed) {
      emit(
        ContactActionsState(
          status: ContactActionStatus.failure,
          failure: failure,
        ),
      );
    }
  }
}
