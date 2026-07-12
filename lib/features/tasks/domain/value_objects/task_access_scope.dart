import 'package:equatable/equatable.dart';

sealed class TaskAccessScope extends Equatable {
  const TaskAccessScope();
}

final class WorkspaceTaskAccess extends TaskAccessScope {
  const WorkspaceTaskAccess();

  @override
  List<Object?> get props => const [];
}

final class AssignedTaskAccess extends TaskAccessScope {
  const AssignedTaskAccess(this.assigneeId);

  final String assigneeId;

  @override
  List<Object?> get props => [assigneeId];
}
