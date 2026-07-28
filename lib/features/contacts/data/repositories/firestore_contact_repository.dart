import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_workspace_activity_mapper.dart';
import 'package:nexuscrm/features/contacts/data/mappers/firestore_contact_failure_mapper.dart';
import 'package:nexuscrm/features/contacts/data/mappers/firestore_contact_mapper.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';

final class FirestoreContactRepository implements ContactRepository {
  FirestoreContactRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CrmContact>> watchContacts({
    required String workspaceId,
    required ContactAccessScope accessScope,
    bool includeArchived = false,
  }) {
    return _watch(() {
      Query<Map<String, dynamic>> query = _contacts(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      );

      if (!includeArchived) {
        query = query.where('isArchived', isEqualTo: false);
      }

      query = switch (accessScope) {
        WorkspaceContactAccess() => query,
        OwnedContactAccess(:final ownerId) => query.where(
          'ownerId',
          isEqualTo: _requiredIdentifier(ownerId, 'ownerId'),
        ),
      };

      return query
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_sortedContacts);
    });
  }

  @override
  Stream<CrmContact?> watchContact({
    required String workspaceId,
    required String contactId,
  }) {
    return _watch(() {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );

      return reference
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(
            (snapshot) => snapshot.exists
                ? FirestoreContactMapper.fromDocument(snapshot)
                : null,
          );
    });
  }

  @override
  Future<String> createLead({
    required String workspaceId,
    required String actorUserId,
    required LeadInput input,
  }) {
    return _execute(() async {
      final normalizedWorkspaceId = _requiredIdentifier(
        workspaceId,
        'workspaceId',
      );
      final reference = _contacts(normalizedWorkspaceId).doc();
      final data = FirestoreContactMapper.createLeadData(
        workspaceId: normalizedWorkspaceId,
        actorUserId: actorUserId,
        input: input,
      );

      await (_firestore.batch()
            ..set(reference, data)
            ..set(
              _activities(normalizedWorkspaceId).doc(),
              FirestoreWorkspaceActivityMapper.leadCreatedData(
                workspaceId: normalizedWorkspaceId,
                contactId: reference.id,
                contactName: input.fullName,
                actorUserId: actorUserId,
              ),
            ))
          .commit();
      return reference.id;
    });
  }

  @override
  Future<void> updateLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required LeadInput input,
  }) {
    return _execute(() async {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );
      final data = FirestoreContactMapper.updateLeadData(
        actorUserId: actorUserId,
        input: input,
      );

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final contact = _existingContact(snapshot);

        if (contact is! Lead) {
          throw const ContactFailure(ContactFailureCode.conflict);
        }

        transaction.update(reference, data);
      });
    });
  }

  @override
  Future<void> updateClient({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required ClientInput input,
  }) {
    return _execute(() async {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );
      final data = FirestoreContactMapper.updateClientData(
        actorUserId: actorUserId,
        input: input,
      );

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final contact = _existingContact(snapshot);

        if (contact is! ClientContact) {
          throw const ContactFailure(ContactFailureCode.conflict);
        }

        transaction.update(reference, data);
      });
    });
  }

  @override
  Future<void> convertLead({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    return _execute(() async {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );
      final data = FirestoreContactMapper.convertLeadData(
        actorUserId: actorUserId,
      );

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final contact = _existingContact(snapshot);

        if (contact is! Lead || contact.isArchived) {
          throw const ContactFailure(ContactFailureCode.conflict);
        }

        transaction
          ..update(reference, data)
          ..set(
            _activities(reference.parent.parent!.id).doc(),
            FirestoreWorkspaceActivityMapper.leadConvertedData(
              workspaceId: contact.workspaceId,
              contactId: contact.id,
              contactName: contact.fullName,
              actorUserId: actorUserId,
            ),
          );
      });
    });
  }

  @override
  Future<void> archiveContact({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
  }) {
    return _execute(() async {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );
      final data = FirestoreContactMapper.archiveContactData(
        actorUserId: actorUserId,
      );

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);
        final contact = _existingContact(snapshot);

        if (!contact.isArchived) {
          transaction.update(reference, data);
        }
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _contacts(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('contacts');
  }

  CollectionReference<Map<String, dynamic>> _activities(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('activities');
  }

  DocumentReference<Map<String, dynamic>> _contactReference({
    required String workspaceId,
    required String contactId,
  }) {
    final normalizedWorkspaceId = _requiredIdentifier(
      workspaceId,
      'workspaceId',
    );
    final normalizedContactId = _requiredIdentifier(contactId, 'contactId');

    return _contacts(normalizedWorkspaceId).doc(normalizedContactId);
  }

  static CrmContact _existingContact(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists) {
      throw const ContactFailure(ContactFailureCode.notFound);
    }

    return FirestoreContactMapper.fromDocument(snapshot);
  }

  static String _requiredIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid contact identifier: $field.');
    }

    return normalized;
  }

  static List<CrmContact> _sortedContacts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final contacts =
        snapshot.docs.map(FirestoreContactMapper.fromDocument).toList()
          ..sort(_compareContacts);

    return List.unmodifiable(contacts);
  }

  static Stream<T> _watch<T>(Stream<T> Function() build) {
    try {
      return build().handleError((Object error) => throw _contactError(error));
    } on Object catch (error) {
      return Stream.error(_contactError(error));
    }
  }

  static Object _contactError(Object error) {
    if (error is ContactFailure) {
      return error;
    }

    if (error is FormatException) {
      return const ContactFailure(ContactFailureCode.invalidData);
    }

    return error is FirebaseException
        ? FirestoreContactFailureMapper.fromFirebase(error)
        : error;
  }

  static int _compareContacts(CrmContact first, CrmContact second) {
    final updatedComparison = second.updatedAt.compareTo(first.updatedAt);

    return updatedComparison != 0
        ? updatedComparison
        : first.id.compareTo(second.id);
  }

  static Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on ContactFailure {
      rethrow;
    } on FormatException {
      throw const ContactFailure(ContactFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreContactFailureMapper.fromFirebase(error);
    }
  }
}
