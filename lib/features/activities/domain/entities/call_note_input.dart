import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_follow_up_input.dart';

final class CallNoteInput extends Equatable {
  const CallNoteInput({
    required this.outcome,
    required this.note,
    this.followUp,
  });

  final CallOutcome outcome;
  final String? note;
  final CallNoteFollowUpInput? followUp;

  @override
  List<Object?> get props => [outcome, note, followUp];
}
