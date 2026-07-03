import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

abstract final class FirestoreMembershipMapper {
  static WorkspaceMembership fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.reference.parent.id != 'members' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid workspace membership path.');
    }

    final workspaceId = _requiredString(data, 'workspaceId');
    final userId = _requiredString(data, 'userId');

    if (workspaceId != workspaceReference.id || userId != document.id) {
      throw const FormatException('Workspace membership IDs do not match.');
    }

    return WorkspaceMembership(
      workspaceId: workspaceId,
      userId: userId,
      role: _parseRole(_requiredString(data, 'role')),
      status: _parseStatus(_requiredString(data, 'status')),
    );
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid workspace membership field: $field.');
    }

    return value;
  }

  static WorkspaceRole _parseRole(String value) {
    return switch (value) {
      'admin' => WorkspaceRole.admin,
      'sales_rep' => WorkspaceRole.salesRep,
      _ => throw FormatException('Unsupported workspace role: $value.'),
    };
  }

  static MembershipStatus _parseStatus(String value) {
    return switch (value) {
      'invited' => MembershipStatus.invited,
      'active' => MembershipStatus.active,
      'suspended' => MembershipStatus.suspended,
      'revoked' => MembershipStatus.revoked,
      _ => throw FormatException('Unsupported membership status: $value.'),
    };
  }
}
