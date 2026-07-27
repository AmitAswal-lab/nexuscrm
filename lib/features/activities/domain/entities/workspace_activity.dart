import 'package:equatable/equatable.dart';

enum WorkspaceActivityType {
  callLogged,
  leadCreated,
  leadConverted,
  taskCompleted,
}

final class WorkspaceActivity extends Equatable {
  const WorkspaceActivity({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.contactId,
    required this.actorUserId,
    required this.createdAt,
    this.contactName,
    this.detail,
  });

  final String id;
  final String workspaceId;
  final WorkspaceActivityType type;
  final String contactId;
  final String actorUserId;
  final DateTime createdAt;
  final String? contactName;
  final String? detail;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    type,
    contactId,
    actorUserId,
    createdAt,
    contactName,
    detail,
  ];
}
