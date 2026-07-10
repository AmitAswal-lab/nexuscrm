import 'package:equatable/equatable.dart';

final class SalesAssignee extends Equatable {
  const SalesAssignee({
    required this.userId,
    required this.workspaceId,
    required this.displayName,
    required this.email,
  });

  final String userId;
  final String workspaceId;
  final String displayName;
  final String email;

  @override
  List<Object> get props => [userId, workspaceId, displayName, email];
}
