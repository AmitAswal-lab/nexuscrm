part of 'lead_form_cubit.dart';

enum AssigneeDirectoryStatus { loading, ready, failure }

enum LeadFormSubmissionStatus {
  initial,
  submitting,
  waitingForSync,
  success,
  failure,
}

final class LeadFormState extends Equatable {
  const LeadFormState({
    required this.assigneeStatus,
    this.assignees = const <SalesAssignee>[],
    this.submissionStatus = LeadFormSubmissionStatus.initial,
    this.assigneeFailure,
    this.submissionFailure,
  });

  final AssigneeDirectoryStatus assigneeStatus;
  final List<SalesAssignee> assignees;
  final LeadFormSubmissionStatus submissionStatus;
  final ContactFailure? assigneeFailure;
  final ContactFailure? submissionFailure;

  LeadFormState copyWith({
    AssigneeDirectoryStatus? assigneeStatus,
    List<SalesAssignee>? assignees,
    LeadFormSubmissionStatus? submissionStatus,
    ContactFailure? assigneeFailure,
    ContactFailure? submissionFailure,
    bool clearAssigneeFailure = false,
    bool clearSubmissionFailure = false,
  }) {
    return LeadFormState(
      assigneeStatus: assigneeStatus ?? this.assigneeStatus,
      assignees: assignees ?? this.assignees,
      submissionStatus: submissionStatus ?? this.submissionStatus,
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
    assigneeStatus,
    assignees,
    submissionStatus,
    assigneeFailure,
    submissionFailure,
  ];
}
