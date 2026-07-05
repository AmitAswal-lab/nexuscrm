part of 'contact_detail_cubit.dart';

enum ContactDetailStatus { loading, success, notFound, failure }

final class ContactDetailState extends Equatable {
  const ContactDetailState({
    this.status = ContactDetailStatus.loading,
    this.contact,
    this.failure,
  });

  final ContactDetailStatus status;
  final CrmContact? contact;
  final ContactFailure? failure;

  @override
  List<Object?> get props => [status, contact, failure];
}
