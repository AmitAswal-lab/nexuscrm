part of 'contact_edit_cubit.dart';

enum ContactEditStatus { loading, ready, notFound, failure }

enum ContactEditAssigneeStatus { loading, ready, failure }

enum ContactEditSubmissionStatus {
  initial,
  submitting,
  waitingForSync,
  success,
  failure,
}

final class ContactEditState extends Equatable {
  const ContactEditState({
    this.status = ContactEditStatus.loading,
    this.contact,
    this.assignees = const <SalesAssignee>[],
    this.assigneeStatus = ContactEditAssigneeStatus.ready,
    this.submissionStatus = ContactEditSubmissionStatus.initial,
    this.failure,
    this.assigneeFailure,
    this.submissionFailure,
  });

  final ContactEditStatus status;
  final CrmContact? contact;
  final List<SalesAssignee> assignees;
  final ContactEditAssigneeStatus assigneeStatus;
  final ContactEditSubmissionStatus submissionStatus;
  final ContactFailure? failure;
  final ContactFailure? assigneeFailure;
  final ContactFailure? submissionFailure;

  ContactEditState copyWith({
    ContactEditStatus? status,
    CrmContact? contact,
    List<SalesAssignee>? assignees,
    ContactEditAssigneeStatus? assigneeStatus,
    ContactEditSubmissionStatus? submissionStatus,
    ContactFailure? failure,
    ContactFailure? assigneeFailure,
    ContactFailure? submissionFailure,
    bool clearContact = false,
    bool clearFailure = false,
    bool clearAssigneeFailure = false,
    bool clearSubmissionFailure = false,
  }) {
    return ContactEditState(
      status: status ?? this.status,
      contact: clearContact ? null : contact ?? this.contact,
      assignees: assignees ?? this.assignees,
      assigneeStatus: assigneeStatus ?? this.assigneeStatus,
      submissionStatus: submissionStatus ?? this.submissionStatus,
      failure: clearFailure ? null : failure ?? this.failure,
      assigneeFailure: clearAssigneeFailure
          ? null
          : assigneeFailure ?? this.assigneeFailure,
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
    assigneeStatus,
    submissionStatus,
    failure,
    assigneeFailure,
    submissionFailure,
  ];
}
