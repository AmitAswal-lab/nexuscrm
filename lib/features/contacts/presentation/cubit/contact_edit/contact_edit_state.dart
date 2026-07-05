part of 'contact_edit_cubit.dart';

enum ContactEditStatus { loading, ready, notFound, failure }

enum ContactEditSubmissionStatus { initial, submitting, success, failure }

final class ContactEditState extends Equatable {
  const ContactEditState({
    this.status = ContactEditStatus.loading,
    this.contact,
    this.assignees = const <SalesAssignee>[],
    this.submissionStatus = ContactEditSubmissionStatus.initial,
    this.failure,
    this.submissionFailure,
  });

  final ContactEditStatus status;
  final CrmContact? contact;
  final List<SalesAssignee> assignees;
  final ContactEditSubmissionStatus submissionStatus;
  final ContactFailure? failure;
  final ContactFailure? submissionFailure;

  ContactEditState copyWith({
    ContactEditSubmissionStatus? submissionStatus,
    ContactFailure? submissionFailure,
    bool clearSubmissionFailure = false,
  }) {
    return ContactEditState(
      status: status,
      contact: contact,
      assignees: assignees,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      failure: failure,
      submissionFailure: clearSubmissionFailure
          ? null
          : submissionFailure ?? this.submissionFailure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    contact,
    assignees,
    submissionStatus,
    failure,
    submissionFailure,
  ];
}
