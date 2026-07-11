import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';

final class TaskInput extends Equatable {
  const TaskInput({
    required this.contactId,
    required this.kind,
    required this.title,
    required this.notes,
    required this.assigneeId,
    required this.dueOn,
  });

  final String contactId;
  final TaskKind kind;
  final String title;
  final String? notes;
  final String assigneeId;

  /// An ISO 8601 calendar date (`YYYY-MM-DD`), deliberately without a time.
  final String dueOn;

  @override
  List<Object?> get props => [contactId, kind, title, notes, assigneeId, dueOn];
}
