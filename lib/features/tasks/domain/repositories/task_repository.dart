import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

abstract interface class TaskRepository {
  Stream<List<CrmTask>> watchTasks({
    required String workspaceId,
    required TaskAccessScope accessScope,
  });

  Stream<CrmTask?> watchTask({
    required String workspaceId,
    required String taskId,
  });

  Stream<List<CrmTask>> watchContactTasks({
    required String workspaceId,
    required String contactId,
    required TaskAccessScope accessScope,
  });

  Future<String> createTask({
    required String workspaceId,
    required String actorUserId,
    required TaskInput input,
  });

  Future<void> updateTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
    required TaskInput input,
  });

  Future<void> completeTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  });

  Future<void> reopenTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  });
}
