import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_archive_filter.dart';

part 'archived_contacts_state.dart';

final class ArchivedContactsCubit extends Cubit<ArchivedContactsState> {
  factory ArchivedContactsCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required ContactAccessScope accessScope,
    required String actorUserId,
  }) {
    return ArchivedContactsCubit._(
      contactRepository,
      workspaceId,
      accessScope,
      actorUserId,
    );
  }

  ArchivedContactsCubit._(
    this._contactRepository,
    this._workspaceId,
    this._accessScope,
    this._actorUserId,
  ) : super(const ArchivedContactsState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final ContactAccessScope _accessScope;
  final String _actorUserId;

  StreamSubscription<List<CrmContact>>? _subscription;

  Future<void> load() async {
    unawaited(_subscription?.cancel());

    if (isClosed) {
      return;
    }

    emit(state.copyWith(status: ArchivedContactsStatus.loading));

    _subscription = _contactRepository
        .watchContacts(
          workspaceId: _workspaceId,
          accessScope: _accessScope,
          archiveFilter: ContactArchiveFilter.archived,
        )
        .listen(_onContacts, onError: _onError);
  }

  Future<void> restore(String contactId) async {
    if (state.restoringContactId != null) {
      return;
    }

    emit(
      state.copyWith(restoringContactId: contactId, clearActionFailure: true),
    );

    try {
      await _contactRepository.restoreContact(
        workspaceId: _workspaceId,
        contactId: contactId,
        actorUserId: _actorUserId,
      );

      if (!isClosed) {
        emit(state.copyWith(clearRestoring: true));
      }
    } on Object catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(
            clearRestoring: true,
            actionFailure: error is ContactFailure
                ? error
                : const ContactFailure(ContactFailureCode.unknown),
          ),
        );
      }
    }
  }

  void _onContacts(List<CrmContact> contacts) {
    if (!isClosed) {
      emit(
        state.copyWith(
          status: ArchivedContactsStatus.success,
          contacts: contacts,
        ),
      );
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(
          status: ArchivedContactsStatus.failure,
          failure: error is ContactFailure
              ? error
              : const ContactFailure(ContactFailureCode.unknown),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
