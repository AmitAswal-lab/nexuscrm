import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';

part 'sales_dashboard_state.dart';

final class SalesDashboardCubit extends Cubit<SalesDashboardState> {
  factory SalesDashboardCubit({
    required ContactRepository contactRepository,
    required String workspaceId,
    required String ownerId,
  }) {
    return SalesDashboardCubit._(contactRepository, workspaceId, ownerId);
  }

  SalesDashboardCubit._(
    this._contactRepository,
    this._workspaceId,
    this._ownerId,
  ) : super(const SalesDashboardState()) {
    unawaited(load());
  }

  final ContactRepository _contactRepository;
  final String _workspaceId;
  final String _ownerId;

  StreamSubscription<List<CrmContact>>? _subscription;

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
  }

  void _onContacts(List<CrmContact> contacts) {
    if (!isClosed) {
      emit(
        SalesDashboardState(
          status: SalesDashboardStatus.success,
          contacts: contacts,
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
    return super.close();
  }
}
