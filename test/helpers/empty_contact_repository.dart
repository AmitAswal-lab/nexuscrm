import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_archive_filter.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';
import 'package:nexuscrm/features/documents/domain/services/share_launcher.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

final class EmptyActivityRepository implements ActivityRepository {
  const EmptyActivityRepository();

  @override
  Stream<List<WorkspaceActivity>> watchWorkspaceActivity({
    required String workspaceId,
    DateTime? since,
    String? actorUserId,
    WorkspaceActivityType? type,
    int limit = 50,
  }) => Stream.value(const <WorkspaceActivity>[]);

  @override
  Future<String> createCallNote({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required CallNoteInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<CallNote>> watchCallNotes({
    required String workspaceId,
    required String contactId,
  }) {
    return Stream.value(const <CallNote>[]);
  }
}

final class EmptyContactRepository implements ContactRepository {
  const EmptyContactRepository();

  @override
  Stream<CrmContact?> watchContact({
    required String workspaceId,
    required String contactId,
  }) {
    return Stream.value(null);
  }

  @override
  Stream<List<CrmContact>> watchContacts({
    required String workspaceId,
    required ContactAccessScope accessScope,
    ContactArchiveFilter archiveFilter = ContactArchiveFilter.active,
  }) {
    return Stream.value(const <CrmContact>[]);
  }

  @override
  Future<void> archiveContact({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreContact({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> convertLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> createLead({
    required String workspaceId,
    required String actorUserId,
    required LeadInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateClient({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required ClientInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required LeadInput input,
  }) {
    throw UnimplementedError();
  }
}

final class EmptySalesAssigneeRepository implements SalesAssigneeRepository {
  const EmptySalesAssigneeRepository();

  @override
  Stream<List<SalesAssignee>> watchActiveSalesAssignees({
    required String workspaceId,
  }) {
    return Stream.value(const <SalesAssignee>[]);
  }
}

final class EmptyTaskRepository implements TaskRepository {
  const EmptyTaskRepository();

  @override
  Future<void> completeTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> createTask({
    required String workspaceId,
    required String actorUserId,
    required TaskInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> reopenTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTask({
    required String workspaceId,
    required String taskId,
    required String actorUserId,
    required TaskInput input,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<CrmTask?> watchTask({
    required String workspaceId,
    required String taskId,
  }) {
    return Stream.value(null);
  }

  @override
  Stream<List<CrmTask>> watchTasks({
    required String workspaceId,
    required TaskAccessScope accessScope,
  }) {
    return Stream.value(const <CrmTask>[]);
  }

  @override
  Stream<List<CrmTask>> watchContactTasks({
    required String workspaceId,
    required String contactId,
    required TaskAccessScope accessScope,
  }) {
    return Stream.value(const <CrmTask>[]);
  }
}

final class EmptyAdminTeamRepository implements AdminTeamRepository {
  const EmptyAdminTeamRepository();

  @override
  Stream<List<TeamMember>> watchTeam({required String workspaceId}) =>
      Stream.value(const <TeamMember>[]);
}

final class EmptyDocumentRepository implements DocumentRepository {
  const EmptyDocumentRepository();

  @override
  Stream<List<WorkspaceDocument>> watchDocuments({
    required String workspaceId,
    bool includeRetired = false,
  }) => Stream.value(const <WorkspaceDocument>[]);

  @override
  Stream<List<DocumentShare>> watchContactShares({
    required String workspaceId,
    required String contactId,
    String? sharedByUserId,
  }) => Stream.value(const <DocumentShare>[]);

  @override
  Future<String> uploadDocument({
    required String workspaceId,
    required String actorUserId,
    required DocumentUpload upload,
  }) => throw UnimplementedError();

  @override
  Future<void> retireDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  }) => throw UnimplementedError();

  @override
  Future<void> restoreDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> createShareLink({
    required String workspaceId,
    required String documentId,
    required String contactId,
    required String actorUserId,
    required ShareChannel channel,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeShare({
    required String workspaceId,
    required String shareId,
    required String actorUserId,
  }) => throw UnimplementedError();
}

final class SilentShareLauncher implements ShareLauncher {
  const SilentShareLauncher();

  @override
  Future<bool> share({
    required ShareChannel channel,
    required String recipient,
    required String subject,
    required String message,
  }) async => true;
}
