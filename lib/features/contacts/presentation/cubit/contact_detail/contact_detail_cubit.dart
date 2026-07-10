import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';

part 'contact_detail_state.dart';

final class ContactDetailCubit extends Cubit<ContactDetailState> {
  factory ContactDetailCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required String contactId,
  }) {
    return ContactDetailCubit._(contactRepository, workspaceId, contactId);
  }

  ContactDetailCubit._(
    this._contactRepository,
    this._workspaceId,
    this._contactId,
  ) : super(const ContactDetailState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final String _contactId;

  StreamSubscription<CrmContact?>? _subscription;

  Future<void> load() async {
    await _subscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(const ContactDetailState());
    _subscription = _contactRepository
        .watchContact(workspaceId: _workspaceId, contactId: _contactId)
        .listen(_onContact, onError: _onError);
  }

  void _onContact(CrmContact? contact) {
    if (isClosed) {
      return;
    }

    emit(
      contact == null
          ? const ContactDetailState(status: ContactDetailStatus.notFound)
          : ContactDetailState(
              status: ContactDetailStatus.success,
              contact: contact,
            ),
    );
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        ContactDetailState(
          status: ContactDetailStatus.failure,
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
    return super.close();
  }
}
