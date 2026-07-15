import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';

final class FirestoreInvitationDirectoryRepository
    implements InvitationDirectoryRepository {
  FirestoreInvitationDirectoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<WorkspaceInvitation>> watchPendingInvitations({
    required String workspaceId,
  }) {
    final id = workspaceId.trim();
    if (id.isEmpty || id.contains('/')) throw const FormatException();

    return _firestore
        .collection('workspaces')
        .doc(id)
        .collection('invitations')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => List.unmodifiable(
            snapshot.docs.map(_fromDocument).toList(growable: false),
          ),
        );
  }

  static WorkspaceInvitation _fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceId = document.reference.parent.parent?.id;
    if (data == null ||
        workspaceId == null ||
        data['workspaceId'] != workspaceId) {
      throw const FormatException('Invalid invitation data.');
    }

    return WorkspaceInvitation(
      id: document.id,
      workspaceId: workspaceId,
      email: _string(data, 'email'),
      role: _string(data, 'role'),
      status: _status(_string(data, 'status')),
      invitedByUserId: _string(data, 'invitedByUserId'),
      createdAt: _timestamp(data, 'createdAt'),
      updatedAt: _timestamp(data, 'updatedAt'),
      expiresAt: _timestamp(data, 'expiresAt'),
      lastSentAt: data['lastSentAt'] is Timestamp
          ? (data['lastSentAt'] as Timestamp).toDate()
          : null,
      deliveryStatus: _deliveryStatus(_string(data, 'deliveryStatus')),
      resendCount: data['resendCount'] is int ? data['resendCount'] as int : 0,
      acceptedAt: _nullableTimestamp(data, 'acceptedAt'),
      acceptedByUserId: _nullableString(data, 'acceptedByUserId'),
      revokedAt: _nullableTimestamp(data, 'revokedAt'),
      revokedByUserId: _nullableString(data, 'revokedByUserId'),
    );
  }

  static String _string(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Invalid invitation data.');
    }
    return value;
  }

  static String? _nullableString(Map<String, dynamic> data, String key) =>
      data[key] is String ? data[key] as String : null;

  static DateTime _timestamp(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! Timestamp) {
      throw const FormatException('Invalid invitation data.');
    }
    return value.toDate();
  }

  static DateTime? _nullableTimestamp(Map<String, dynamic> data, String key) =>
      data[key] is Timestamp ? (data[key] as Timestamp).toDate() : null;

  static InvitationStatus _status(String value) => switch (value) {
    'pending' => InvitationStatus.pending,
    'accepted' => InvitationStatus.accepted,
    'expired' => InvitationStatus.expired,
    'revoked' => InvitationStatus.revoked,
    _ => throw const FormatException('Invalid invitation data.'),
  };

  static InvitationDeliveryStatus _deliveryStatus(String value) =>
      switch (value) {
        'pending' => InvitationDeliveryStatus.pending,
        'sending' => InvitationDeliveryStatus.sending,
        'sent' => InvitationDeliveryStatus.sent,
        'failed' => InvitationDeliveryStatus.failed,
        _ => throw const FormatException('Invalid invitation data.'),
      };
}
