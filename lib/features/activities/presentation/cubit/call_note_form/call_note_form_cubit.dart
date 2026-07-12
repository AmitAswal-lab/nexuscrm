import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';

part 'call_note_form_state.dart';

final class CallNoteFormCubit extends Cubit<CallNoteFormState> {
  CallNoteFormCubit({
    required this.activityRepository,
    required this.workspaceId,
    required this.contactId,
    required this.actorUserId,
  }) : super(const CallNoteFormState());

  final ActivityRepository activityRepository;
  final String workspaceId;
  final String contactId;
  final String actorUserId;

  Future<void> submit(CallNoteInput input) async {
    if (state.submissionStatus == CallNoteSubmissionStatus.submitting) {
      return;
    }

    emit(
      state.copyWith(
        submissionStatus: CallNoteSubmissionStatus.submitting,
        clearFailure: true,
      ),
    );

    try {
      await activityRepository.createCallNote(
        workspaceId: workspaceId,
        contactId: contactId,
        actorUserId: actorUserId,
        input: input,
      );
      emit(state.copyWith(submissionStatus: CallNoteSubmissionStatus.success));
    } on Object catch (error) {
      emit(
        state.copyWith(
          submissionStatus: CallNoteSubmissionStatus.failure,
          failure: error is ActivityFailure
              ? error
              : const ActivityFailure(ActivityFailureCode.unknown),
        ),
      );
    }
  }
}
