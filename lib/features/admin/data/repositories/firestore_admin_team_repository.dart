import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

final class FirestoreAdminTeamRepository implements AdminTeamRepository {
  FirestoreAdminTeamRepository(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Stream<List<TeamMember>> watchTeam({required String workspaceId}) {
    final id = workspaceId.trim();

    if (id.isEmpty || id.contains('/')) {
      return Stream.error(const FormatException());
    }

    return _firestore
        .collection('workspaces')
        .doc(id)
        .collection('members')
        .snapshots()
        .where((snapshot) => !snapshot.metadata.hasPendingWrites)
        .map(_sortedMembers);
  }

  static List<TeamMember> _sortedMembers(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final members =
        snapshot.docs
            .map(_fromDocument)
            .where((member) => member.status != MembershipStatus.invited)
            .toList()
          ..sort((a, b) => _label(a).compareTo(_label(b)));

    return List.unmodifiable(members);
  }

  static TeamMember _fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null ||
        data['workspaceId'] != doc.reference.parent.parent?.id ||
        data['userId'] != doc.id ||
        data['userId'] is! String) {
      throw const FormatException();
    }
    final role = switch (data['role']) {
      'admin' => WorkspaceRole.admin,
      'sales_rep' => WorkspaceRole.salesRep,
      _ => throw const FormatException(),
    };
    final status = switch (data['status']) {
      'invited' => MembershipStatus.invited,
      'active' => MembershipStatus.active,
      'suspended' => MembershipStatus.suspended,
      'revoked' => MembershipStatus.revoked,
      _ => throw const FormatException(),
    };
    return TeamMember(
      userId: doc.id,
      displayName: data['displayName'] is String ? data['displayName'] : null,
      email: data['email'] is String ? data['email'] : null,
      role: role,
      status: status,
    );
  }

  static String _label(TeamMember member) =>
      (member.displayName ?? member.email ?? member.userId).toLowerCase();
}
