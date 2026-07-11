import 'package:equatable/equatable.dart';

enum CallOutcome { connected, voicemail, noAnswer, wrongNumber, other }

/// An immutable record of a call made from a CRM contact.
final class CallNote extends Equatable {
  const CallNote({
    required this.id,
    required this.workspaceId,
    required this.contactId,
    required this.outcome,
    required this.note,
    required this.actorUserId,
    required this.createdAt,
    required this.nextTaskId,
  });

  final String id;
  final String workspaceId;
  final String contactId;
  final CallOutcome outcome;
  final String? note;
  final String actorUserId;
  final DateTime createdAt;

  /// The optional task created from this call in a later workflow checkpoint.
  final String? nextTaskId;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    contactId,
    outcome,
    note,
    actorUserId,
    createdAt,
    nextTaskId,
  ];
}
