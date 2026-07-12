part of 'call_note_form_cubit.dart';

enum CallNoteSubmissionStatus { idle, submitting, success, failure }

final class CallNoteFormState extends Equatable {
  const CallNoteFormState({
    this.submissionStatus = CallNoteSubmissionStatus.idle,
    this.failure,
  });

  final CallNoteSubmissionStatus submissionStatus;
  final ActivityFailure? failure;

  CallNoteFormState copyWith({
    CallNoteSubmissionStatus? submissionStatus,
    ActivityFailure? failure,
    bool clearFailure = false,
  }) {
    return CallNoteFormState(
      submissionStatus: submissionStatus ?? this.submissionStatus,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  List<Object?> get props => [submissionStatus, failure];
}
