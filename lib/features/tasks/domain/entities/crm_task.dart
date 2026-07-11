import 'package:equatable/equatable.dart';

enum TaskKind { task, followUp }

enum TaskStatus { open, completed }

final class CrmTask extends Equatable {
  const CrmTask({
    required this.id,
    required this.workspaceId,
    required this.contactId,
    required this.kind,
    required this.title,
    required this.notes,
    required this.assigneeId,
    required this.dueOn,
    required this.status,
    required this.completionCount,
    required this.lastCompletedAt,
    required this.lastCompletedByUserId,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String contactId;
  final TaskKind kind;
  final String title;
  final String? notes;
  final String assigneeId;

  /// An ISO 8601 calendar date (`YYYY-MM-DD`), deliberately without a time.
  final String dueOn;
  final TaskStatus status;
  final int completionCount;
  final DateTime? lastCompletedAt;
  final String? lastCompletedByUserId;
  final String createdByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == TaskStatus.completed;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    contactId,
    kind,
    title,
    notes,
    assigneeId,
    dueOn,
    status,
    completionCount,
    lastCompletedAt,
    lastCompletedByUserId,
    createdByUserId,
    updatedByUserId,
    createdAt,
    updatedAt,
  ];
}
