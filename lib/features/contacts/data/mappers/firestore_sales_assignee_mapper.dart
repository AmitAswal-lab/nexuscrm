import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';

abstract final class FirestoreSalesAssigneeMapper {
  static SalesAssignee fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.reference.parent.id != 'members' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid sales assignee path.');
    }

    final workspaceId = _requiredString(data, 'workspaceId');
    final userId = _requiredString(data, 'userId');

    if (workspaceId != workspaceReference.id ||
        userId != document.id ||
        data['role'] != 'sales_rep' ||
        data['status'] != 'active') {
      throw const FormatException('Invalid active sales membership.');
    }

    final email = _requiredString(data, 'email');

    return SalesAssignee(
      userId: userId,
      workspaceId: workspaceId,
      displayName: _optionalString(data, 'displayName') ?? email,
      email: email,
    );
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];

    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid sales assignee field: $field.');
    }

    return value.trim();
  }
}
