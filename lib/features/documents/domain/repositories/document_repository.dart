import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';

abstract interface class DocumentRepository {
  Stream<List<WorkspaceDocument>> watchDocuments({
    required String workspaceId,
    bool includeRetired = false,
  });

  Stream<List<DocumentShare>> watchContactShares({
    required String workspaceId,
    required String contactId,
  });

  Future<String> uploadDocument({
    required String workspaceId,
    required String actorUserId,
    required DocumentUpload upload,
  });

  Future<void> retireDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  });

  Future<void> restoreDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  });

  /// Creates a share and returns the link the client should send.
  Future<String> createShareLink({
    required String workspaceId,
    required String documentId,
    required String contactId,
    required String actorUserId,
    required ShareChannel channel,
  });

  Future<void> revokeShare({
    required String workspaceId,
    required String shareId,
    required String actorUserId,
  });
}
