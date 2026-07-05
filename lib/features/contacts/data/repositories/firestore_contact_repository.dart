import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) async* {
    try {
      final normalizedWorkspaceId = _requiredIdentifier(
        workspaceId,
        'workspaceId',
      );
      Query<Map<String, dynamic>> query = _contacts(normalizedWorkspaceId);

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

      query = query.orderBy('updatedAt', descending: true);

      await for (final snapshot in query.snapshots()) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        final contacts =
            snapshot.docs.map(FirestoreContactMapper.fromDocument).toList()
              ..sort(_compareContacts);

        yield List.unmodifiable(contacts);
      }
    } on ContactFailure {
      rethrow;
    } on FormatException {
      throw const ContactFailure(ContactFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreContactFailureMapper.fromFirebase(error);
    }
  }

  @override
  Stream<CrmContact?> watchContact({
    required String workspaceId,
    required String contactId,
  }) async* {
    try {
      final reference = _contactReference(
        workspaceId: workspaceId,
        contactId: contactId,
      );

      await for (final snapshot in reference.snapshots()) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        yield snapshot.exists
            ? FirestoreContactMapper.fromDocument(snapshot)
            : null;
      }
    } on ContactFailure {
      rethrow;
    } on FormatException {
      throw const ContactFailure(ContactFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreContactFailureMapper.fromFirebase(error);
    }
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

      await reference.set(data);
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

        transaction.update(reference, data);
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
