import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';

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
    bool includeArchived = false,
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
