import 'package:equatable/equatable.dart';

enum ShareChannel { whatsApp, email }

final class DocumentShare extends Equatable {
  const DocumentShare({
    required this.id,
    required this.workspaceId,
    required this.documentId,
    required this.documentTitle,
    required this.contactId,
    required this.contactName,
    required this.channel,
    required this.sharedByUserId,
    required this.createdAt,
    required this.expiresAt,
    required this.revokedAt,
    required this.openCount,
    required this.lastOpenedAt,
  });

  final String id;
  final String workspaceId;
  final String documentId;
  final String documentTitle;
  final String contactId;
  final String contactName;
  final ShareChannel channel;
  final String sharedByUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? revokedAt;
  final int openCount;
  final DateTime? lastOpenedAt;

  bool get isRevoked => revokedAt != null;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool isActiveAt(DateTime now) => !isRevoked && !isExpiredAt(now);

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    documentId,
    documentTitle,
    contactId,
    contactName,
    channel,
    sharedByUserId,
    createdAt,
    expiresAt,
    revokedAt,
    openCount,
    lastOpenedAt,
  ];
}
