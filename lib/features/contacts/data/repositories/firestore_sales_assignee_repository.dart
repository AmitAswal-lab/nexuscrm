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
  }) {
    try {
      return _firestore
          .collection('workspaces')
          .doc(_requiredIdentifier(workspaceId))
          .collection('members')
          .where('role', isEqualTo: 'sales_rep')
          .where('status', isEqualTo: 'active')
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_sortedAssignees)
          .handleError((Object error) => throw _assigneeError(error));
    } on Object catch (error) {
      return Stream.error(_assigneeError(error));
    }
  }

  static List<SalesAssignee> _sortedAssignees(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final assignees = <SalesAssignee>[];

    for (final document in snapshot.docs) {
      try {
        assignees.add(FirestoreSalesAssigneeMapper.fromDocument(document));
      } on FormatException {
        continue;
      }
    }

    return List.unmodifiable(assignees..sort(_compareAssignees));
  }

  static Object _assigneeError(Object error) {
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
