import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';

abstract final class FirestoreDocumentMapper {
  static WorkspaceDocument fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final workspaceReference = snapshot.reference.parent.parent;

    if (data == null ||
        snapshot.reference.parent.id != 'documents' ||
        workspaceReference == null) {
      throw const FormatException('Invalid document path.');
    }

    final workspaceId = _requiredString(data, 'workspaceId');

    if (workspaceId != workspaceReference.id) {
      throw const FormatException('Document workspace ID does not match path.');
    }

    return WorkspaceDocument(
      id: snapshot.id,
      workspaceId: workspaceId,
      title: _requiredString(data, 'title'),
      description: _optionalString(data, 'description'),
      storagePath: _requiredString(data, 'storagePath'),
      contentType: _requiredString(data, 'contentType'),
      sizeBytes: _requiredPositiveInt(data, 'sizeBytes'),
      isRetired: _requiredBool(data, 'isRetired'),
      uploadedByUserId: _requiredString(data, 'uploadedByUserId'),
      updatedByUserId: _requiredString(data, 'updatedByUserId'),
      createdAt: _requiredTimestamp(data, 'createdAt'),
      updatedAt: _requiredTimestamp(data, 'updatedAt'),
    );
  }

  static Map<String, Object?> createDocumentData({
    required String workspaceId,
    required String actorUserId,
    required String title,
    required String? description,
    required String storagePath,
    required String contentType,
    required int sizeBytes,
  }) {
    final normalizedTitle = title.trim();
    final normalizedDescription = description?.trim();

    if (normalizedTitle.isEmpty || normalizedTitle.length > 120) {
      throw const FormatException('Invalid document title.');
    }

    if (normalizedDescription != null && normalizedDescription.length > 1000) {
      throw const FormatException('Document description is too long.');
    }

    if (sizeBytes <= 0) {
      throw const FormatException('Invalid document size.');
    }

    return <String, Object?>{
      'workspaceId': workspaceId,
      'title': normalizedTitle,
      'description': normalizedDescription == null ||
              normalizedDescription.isEmpty
          ? null
          : normalizedDescription,
      'storagePath': storagePath,
      'contentType': contentType,
      'sizeBytes': sizeBytes,
      'isRetired': false,
      'uploadedByUserId': actorUserId,
      'updatedByUserId': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> retirementData({
    required String actorUserId,
    required bool isRetired,
  }) {
    return <String, Object?>{
      'isRetired': isRetired,
      'updatedByUserId': actorUserId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DocumentShare shareFromDocument(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (data == null) {
      throw const FormatException('Invalid share document.');
    }

    return DocumentShare(
      id: snapshot.id,
      workspaceId: _requiredString(data, 'workspaceId'),
      documentId: _requiredString(data, 'documentId'),
      documentTitle: _requiredString(data, 'documentTitle'),
      contactId: _requiredString(data, 'contactId'),
      contactName: _requiredString(data, 'contactName'),
      channel: _channel(_requiredString(data, 'channel')),
      sharedByUserId: _requiredString(data, 'sharedByUserId'),
      createdAt: _requiredTimestamp(data, 'createdAt'),
      expiresAt: _requiredTimestamp(data, 'expiresAt'),
      revokedAt: _optionalTimestamp(data, 'revokedAt'),
      openCount: _requiredNonNegativeInt(data, 'openCount'),
      lastOpenedAt: _optionalTimestamp(data, 'lastOpenedAt'),
    );
  }

  static Map<String, Object?> createShareData({
    required String workspaceId,
    required String documentId,
    required String documentTitle,
    required String contactId,
    required String contactName,
    required ShareChannel channel,
    required String token,
    required String actorUserId,
    required DateTime expiresAt,
  }) {
    return <String, Object?>{
      'workspaceId': workspaceId,
      'documentId': documentId,
      'documentTitle': documentTitle,
      'contactId': contactId,
      'contactName': contactName,
      'channel': channelName(channel),
      'token': token,
      'sharedByUserId': actorUserId,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'revokedAt': null,
      'openCount': 0,
      'lastOpenedAt': null,
    };
  }

  static Map<String, Object?> revokeShareData() {
    return <String, Object?>{'revokedAt': FieldValue.serverTimestamp()};
  }

  static String channelName(ShareChannel channel) => switch (channel) {
    ShareChannel.whatsApp => 'whatsapp',
    ShareChannel.email => 'email',
  };

  static ShareChannel _channel(String value) => switch (value) {
    'whatsapp' => ShareChannel.whatsApp,
    'email' => ShareChannel.email,
    _ => throw FormatException('Unsupported share channel: $value.'),
  };

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid document field: $field.');
    }

    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid optional document field: $field.');
    }

    return value.trim();
  }

  static bool _requiredBool(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! bool) {
      throw FormatException('Invalid document flag: $field.');
    }

    return value;
  }

  static int _requiredPositiveInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! int || value <= 0) {
      throw FormatException('Invalid document number: $field.');
    }

    return value;
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! int || value < 0) {
      throw FormatException('Invalid document number: $field.');
    }

    return value;
  }

  static DateTime _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! Timestamp) {
      throw FormatException('Invalid document timestamp: $field.');
    }

    return value.toDate().toUtc();
  }

  static DateTime? _optionalTimestamp(
    Map<String, dynamic> data,
    String field,
  ) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! Timestamp) {
      throw FormatException('Invalid optional document timestamp: $field.');
    }

    return value.toDate().toUtc();
  }
}
