part of 'call_note_form_cubit.dart';

enum CallNoteSubmissionStatus { idle, submitting, success, failure }

final class CallNoteFormState extends Equatable {
  const CallNoteFormState({
    this.submissionStatus = CallNoteSubmissionStatus.idle,
    this.failure,
    this.assignees = const [],
    this.assigneesReady = false,
    this.assigneesFailed = false,
  });

  final CallNoteSubmissionStatus submissionStatus;
  final ActivityFailure? failure;
  final List<SalesAssignee> assignees;
  final bool assigneesReady;
  final bool assigneesFailed;

  CallNoteFormState copyWith({
    CallNoteSubmissionStatus? submissionStatus,
    ActivityFailure? failure,
    List<SalesAssignee>? assignees,
    bool? assigneesReady,
    bool? assigneesFailed,
    bool clearFailure = false,
  }) {
    return CallNoteFormState(
      submissionStatus: submissionStatus ?? this.submissionStatus,
      failure: clearFailure ? null : failure ?? this.failure,
      assignees: assignees ?? this.assignees,
      assigneesReady: assigneesReady ?? this.assigneesReady,
      assigneesFailed: assigneesFailed ?? this.assigneesFailed,
    );
  }

  @override
  List<Object?> get props => [
    submissionStatus,
    failure,
    assignees,
    assigneesReady,
    assigneesFailed,
  ];
}
