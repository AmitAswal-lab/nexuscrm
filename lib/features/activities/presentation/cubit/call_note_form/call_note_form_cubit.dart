import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/failures/activity_failure.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

part 'call_note_form_state.dart';

final class CallNoteFormCubit extends Cubit<CallNoteFormState> {
  CallNoteFormCubit({
    required this.activityRepository,
    required this.workspaceId,
    required this.contactId,
    required this.actorUserId,
    required this.canAssignFollowUp,
    required this.fixedAssigneeId,
    required SalesAssigneeRepository salesAssigneeRepository,
  }) : super(const CallNoteFormState()) {
    loadAssignees(salesAssigneeRepository);
  }

  final ActivityRepository activityRepository;
  final String workspaceId;
  final String contactId;
  final String actorUserId;
  final bool canAssignFollowUp;
  final String fixedAssigneeId;
  StreamSubscription<List<SalesAssignee>>? _assignees;

  void loadAssignees(SalesAssigneeRepository repository) {
    if (!canAssignFollowUp || _assignees != null) {
      return;
    }

    _assignees = repository
        .watchActiveSalesAssignees(workspaceId: workspaceId)
        .listen(
          (assignees) =>
              emit(state.copyWith(assignees: assignees, assigneesReady: true)),
          onError: (_, _) => emit(state.copyWith(assigneesFailed: true)),
        );
  }

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

  @override
  Future<void> close() async {
    await _assignees?.cancel();
    return super.close();
  }
}
