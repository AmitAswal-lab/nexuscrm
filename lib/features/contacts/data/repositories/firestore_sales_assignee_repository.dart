import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/contacts/data/mappers/firestore_contact_failure_mapper.dart';
import 'package:nexuscrm/features/contacts/data/mappers/firestore_sales_assignee_mapper.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

final class FirestoreSalesAssigneeRepository
    implements SalesAssigneeRepository {
  FirestoreSalesAssigneeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SalesAssignee>> watchActiveSalesAssignees({
    required String workspaceId,
  }) async* {
    try {
      final normalizedWorkspaceId = _requiredIdentifier(workspaceId);
      final snapshots = _firestore
          .collection('workspaces')
          .doc(normalizedWorkspaceId)
          .collection('members')
          .where('role', isEqualTo: 'sales_rep')
          .where('status', isEqualTo: 'active')
          .snapshots();

      await for (final snapshot in snapshots) {
        if (snapshot.metadata.hasPendingWrites) {
          continue;
        }

        final assignees =
            snapshot.docs
                .map(FirestoreSalesAssigneeMapper.fromDocument)
                .toList()
              ..sort(_compareAssignees);

        yield List.unmodifiable(assignees);
      }
    } on ContactFailure {
      rethrow;
    } on FormatException {
      throw const ContactFailure(ContactFailureCode.invalidData);
    } on FirebaseException catch (error) {
      throw FirestoreContactFailureMapper.fromFirebase(error);
    }
  }

  static String _requiredIdentifier(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw const FormatException('Invalid workspace identifier.');
    }

    return normalized;
  }

  static int _compareAssignees(SalesAssignee first, SalesAssignee second) {
    final nameComparison = first.displayName.toLowerCase().compareTo(
      second.displayName.toLowerCase(),
    );

    return nameComparison != 0
        ? nameComparison
        : first.userId.compareTo(second.userId);
  }
}
