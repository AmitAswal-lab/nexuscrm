import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';

part 'contact_list_state.dart';

final class ContactListCubit extends Cubit<ContactListState> {
  factory ContactListCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required ContactAccessScope accessScope,
  }) {
    return ContactListCubit._(contactRepository, workspaceId, accessScope);
  }

  ContactListCubit._(
    this._contactRepository,
    this._workspaceId,
    this._accessScope,
  ) : super(const ContactListState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final ContactAccessScope _accessScope;

  StreamSubscription<List<CrmContact>>? _subscription;

  Future<void> load() async {
    await _subscription?.cancel();

    if (isClosed) {
      return;
    }

    emit(
      ContactListState(
        status: ContactListStatus.loading,
        contacts: state.contacts,
        filter: state.filter,
      ),
    );

    _subscription = _contactRepository
        .watchContacts(workspaceId: _workspaceId, accessScope: _accessScope)
        .listen(_onContacts, onError: _onError);
  }

  void selectFilter(ContactListFilter filter) {
    if (filter != state.filter) {
      emit(state.copyWith(filter: filter));
    }
  }

  void _onContacts(List<CrmContact> contacts) {
    if (!isClosed) {
      emit(
        ContactListState(
          status: ContactListStatus.success,
          contacts: contacts,
          filter: state.filter,
        ),
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (isClosed) {
      return;
    }

    emit(
      ContactListState(
        status: ContactListStatus.failure,
        contacts: state.contacts,
        filter: state.filter,
        failure: error is ContactFailure
            ? error
            : const ContactFailure(ContactFailureCode.unknown),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
