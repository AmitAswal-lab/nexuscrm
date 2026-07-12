import 'package:equatable/equatable.dart';

final class CallNoteFollowUpInput extends Equatable {
  const CallNoteFollowUpInput({
    required this.title,
    required this.dueOn,
    required this.assigneeId,
  });

  final String title;
  final String dueOn;
  final String assigneeId;

  @override
  List<Object> get props => [title, dueOn, assigneeId];
}
