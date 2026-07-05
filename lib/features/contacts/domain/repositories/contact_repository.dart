import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';

abstract interface class ContactRepository {
  Stream<List<CrmContact>> watchContacts({
    required String workspaceId,
    required ContactAccessScope accessScope,
    bool includeArchived = false,
  });

  Stream<CrmContact?> watchContact({
    required String workspaceId,
    required String contactId,
  });

  Future<String> createLead({
    required String workspaceId,
    required String actorUserId,
    required LeadInput input,
  });

  Future<void> updateLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required LeadInput input,
  });

  Future<void> updateClient({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required ClientInput input,
  });

  Future<void> convertLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  });

  Future<void> archiveContact({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  });
}
