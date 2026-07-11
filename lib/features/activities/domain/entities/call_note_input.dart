import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';

final class CallNoteInput extends Equatable {
  const CallNoteInput({required this.outcome, required this.note});

  final CallOutcome outcome;
  final String? note;

  @override
  List<Object?> get props => [outcome, note];
}
