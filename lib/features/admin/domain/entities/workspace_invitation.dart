import 'package:equatable/equatable.dart';

enum InvitationStatus { pending, accepted, expired, revoked }

enum InvitationDeliveryStatus { pending, sending, sent, failed }

extension InvitationStatusTransitions on InvitationStatus {
  bool canTransitionTo(InvitationStatus next) {
    return switch (this) {
      InvitationStatus.pending =>
        next == InvitationStatus.accepted ||
            next == InvitationStatus.expired ||
            next == InvitationStatus.revoked,
      InvitationStatus.accepted ||
      InvitationStatus.expired ||
      InvitationStatus.revoked => false,
    };
  }
}

/// Backend-owned invitation data; clients never write this document directly.
final class WorkspaceInvitation extends Equatable {
  const WorkspaceInvitation({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.role,
    required this.status,
    required this.invitedByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
    required this.lastSentAt,
    required this.deliveryStatus,
    required this.resendCount,
    required this.acceptedAt,
    required this.acceptedByUserId,
    required this.revokedAt,
    required this.revokedByUserId,
  });

  final String id, workspaceId, email, invitedByUserId;
  final String role;
  final InvitationStatus status;
  final DateTime createdAt, updatedAt, expiresAt;
  final DateTime? lastSentAt;
  final InvitationDeliveryStatus deliveryStatus;
  final int resendCount;
  final DateTime? acceptedAt, revokedAt;
  final String? acceptedByUserId, revokedByUserId;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    email,
    role,
    status,
    invitedByUserId,
    createdAt,
    updatedAt,
    expiresAt,
    lastSentAt,
    deliveryStatus,
    resendCount,
    acceptedAt,
    acceptedByUserId,
    revokedAt,
    revokedByUserId,
  ];
}
