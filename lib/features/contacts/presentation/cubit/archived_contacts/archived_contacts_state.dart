part of 'archived_contacts_cubit.dart';

enum ArchivedContactsStatus { loading, success, failure }

final class ArchivedContactsState extends Equatable {
  const ArchivedContactsState({
    this.status = ArchivedContactsStatus.loading,
    this.contacts = const <CrmContact>[],
    this.failure,
    this.restoringContactId,
    this.actionFailure,
  });

  final ArchivedContactsStatus status;
  final List<CrmContact> contacts;
  final ContactFailure? failure;
  final String? restoringContactId;
  final ContactFailure? actionFailure;

  ArchivedContactsState copyWith({
    ArchivedContactsStatus? status,
    List<CrmContact>? contacts,
    ContactFailure? failure,
    String? restoringContactId,
    ContactFailure? actionFailure,
    bool clearRestoring = false,
    bool clearActionFailure = false,
  }) => ArchivedContactsState(
    status: status ?? this.status,
    contacts: contacts ?? this.contacts,
    failure: failure ?? this.failure,
    restoringContactId: clearRestoring
        ? null
        : restoringContactId ?? this.restoringContactId,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
  );

  @override
  List<Object?> get props => [
    status,
    contacts,
    failure,
    restoringContactId,
    actionFailure,
  ];
}
