part of 'contact_list_cubit.dart';

enum ContactListStatus { loading, success, failure }

enum ContactListFilter { all, leads, clients }

final class ContactListState extends Equatable {
  const ContactListState({
    this.status = ContactListStatus.loading,
    this.contacts = const <CrmContact>[],
    this.filter = ContactListFilter.all,
    this.failure,
  });

  final ContactListStatus status;
  final List<CrmContact> contacts;
  final ContactListFilter filter;
  final ContactFailure? failure;

  List<CrmContact> get visibleContacts {
    return switch (filter) {
      ContactListFilter.all => contacts,
      ContactListFilter.leads =>
        contacts
            .where((contact) => contact.kind == ContactKind.lead)
            .toList(growable: false),
      ContactListFilter.clients =>
        contacts
            .where((contact) => contact.kind == ContactKind.client)
            .toList(growable: false),
    };
  }

  ContactListState copyWith({ContactListFilter? filter}) {
    return ContactListState(
      status: status,
      contacts: contacts,
      filter: filter ?? this.filter,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, contacts, filter, failure];
}
