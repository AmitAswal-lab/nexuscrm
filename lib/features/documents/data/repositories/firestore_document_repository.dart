import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:nexuscrm/features/documents/data/mappers/firestore_document_mapper.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';

final class FirestoreDocumentRepository implements DocumentRepository {
  FirestoreDocumentRepository(
    this._firestore, {
    required this.shareLinkBase,
    required this.publishUrl,
    required this.idToken,
    this.shareLifetime = const Duration(days: 7),
    http.Client? client,
  }) : _client = client ?? http.Client();

  final FirebaseFirestore _firestore;
  final String shareLinkBase;
  final String publishUrl;
  final Future<String?> Function() idToken;
  final Duration shareLifetime;
  final http.Client _client;
  static final _random = Random.secure();

  @override
  Stream<List<WorkspaceDocument>> watchDocuments({
    required String workspaceId,
    bool includeRetired = false,
  }) {
    return _watch(() {
      Query<Map<String, dynamic>> query = _documents(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      );

      if (!includeRetired) {
        query = query.where('isRetired', isEqualTo: false);
      }

      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_documentList);
    });
  }

  @override
  Stream<List<DocumentShare>> watchContactShares({
    required String workspaceId,
    required String contactId,
    String? sharedByUserId,
  }) {
    return _watch(() {
      Query<Map<String, dynamic>> query = _shares(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      ).where(
        'contactId',
        isEqualTo: _requiredIdentifier(contactId, 'contactId'),
      );

      if (sharedByUserId != null) {
        query = query.where(
          'sharedByUserId',
          isEqualTo: _requiredIdentifier(sharedByUserId, 'sharedByUserId'),
        );
      }

      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .where((snapshot) => !snapshot.metadata.hasPendingWrites)
          .map(_shareList);
    });
  }

  @override
  Future<String> uploadDocument({
    required String workspaceId,
    required String actorUserId,
    required DocumentUpload upload,
  }) {
    return _execute(() async {
      if (upload.bytes.isEmpty) {
        throw const DocumentFailure(DocumentFailureCode.invalidData);
      }

      if (upload.bytes.length > DocumentUpload.maxSizeBytes) {
        throw const DocumentFailure(DocumentFailureCode.tooLarge);
      }

      final token = await idToken();

      if (token == null || token.isEmpty) {
        throw const DocumentFailure(DocumentFailureCode.sessionExpired);
      }

      final response = await _client.post(
        Uri.parse(publishUrl).replace(
          queryParameters: <String, String>{
            'workspaceId': _requiredIdentifier(workspaceId, 'workspaceId'),
            'title': upload.title.trim(),
            if (upload.description != null &&
                upload.description!.trim().isNotEmpty)
              'description': upload.description!.trim(),
          },
        ),
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': upload.contentType,
        },
        body: upload.bytes,
      );

      if (response.statusCode == 201) {
        final documentId = jsonDecode(response.body)['documentId'];

        if (documentId is String && documentId.isNotEmpty) {
          return documentId;
        }

        throw const DocumentFailure(DocumentFailureCode.unknown);
      }

      throw DocumentFailure(switch (response.statusCode) {
        401 => DocumentFailureCode.sessionExpired,
        403 => DocumentFailureCode.permissionDenied,
        400 => DocumentFailureCode.invalidData,
        413 => DocumentFailureCode.tooLarge,
        503 || 504 => DocumentFailureCode.networkUnavailable,
        _ => DocumentFailureCode.unknown,
      });
    });
  }

  @override
  Future<void> retireDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  }) => _setRetired(
    workspaceId: workspaceId,
    documentId: documentId,
    actorUserId: actorUserId,
    isRetired: true,
  );

  @override
  Future<void> restoreDocument({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
  }) => _setRetired(
    workspaceId: workspaceId,
    documentId: documentId,
    actorUserId: actorUserId,
    isRetired: false,
  );

  @override
  Future<String> createShareLink({
    required String workspaceId,
    required String documentId,
    required String contactId,
    required String actorUserId,
    required ShareChannel channel,
  }) {
    return _execute(() async {
      final normalizedWorkspaceId = _requiredIdentifier(
        workspaceId,
        'workspaceId',
      );
      final normalizedDocumentId = _requiredIdentifier(
        documentId,
        'documentId',
      );
      final normalizedContactId = _requiredIdentifier(contactId, 'contactId');

      final documentSnapshot = await _documents(
        normalizedWorkspaceId,
      ).doc(normalizedDocumentId).get();

      if (!documentSnapshot.exists) {
        throw const DocumentFailure(DocumentFailureCode.notFound);
      }

      final document = FirestoreDocumentMapper.fromDocument(documentSnapshot);

      if (!document.isShareable) {
        throw const DocumentFailure(DocumentFailureCode.conflict);
      }

      final contactSnapshot = await _firestore
          .collection('workspaces')
          .doc(normalizedWorkspaceId)
          .collection('contacts')
          .doc(normalizedContactId)
          .get();
      final contactName = contactSnapshot.data()?['fullName'];

      if (contactName is! String || contactName.trim().isEmpty) {
        throw const DocumentFailure(DocumentFailureCode.notFound);
      }

      final token = _token();

      await _shares(normalizedWorkspaceId).add(
        FirestoreDocumentMapper.createShareData(
          workspaceId: normalizedWorkspaceId,
          documentId: normalizedDocumentId,
          documentTitle: document.title,
          contactId: normalizedContactId,
          contactName: contactName.trim(),
          channel: channel,
          token: token,
          actorUserId: _requiredIdentifier(actorUserId, 'actorUserId'),
          expiresAt: DateTime.now().toUtc().add(shareLifetime),
        ),
      );

      return '$shareLinkBase?token=$token';
    });
  }

  @override
  Future<void> revokeShare({
    required String workspaceId,
    required String shareId,
    required String actorUserId,
  }) {
    return _execute(() async {
      await _shares(_requiredIdentifier(workspaceId, 'workspaceId'))
          .doc(_requiredIdentifier(shareId, 'shareId'))
          .update(FirestoreDocumentMapper.revokeShareData());
    });
  }

  Future<void> _setRetired({
    required String workspaceId,
    required String documentId,
    required String actorUserId,
    required bool isRetired,
  }) {
    return _execute(() async {
      final reference = _documents(
        _requiredIdentifier(workspaceId, 'workspaceId'),
      ).doc(_requiredIdentifier(documentId, 'documentId'));

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        if (!snapshot.exists) {
          throw const DocumentFailure(DocumentFailureCode.notFound);
        }

        if (FirestoreDocumentMapper.fromDocument(snapshot).isRetired ==
            isRetired) {
          return;
        }

        transaction.update(
          reference,
          FirestoreDocumentMapper.retirementData(
            actorUserId: _requiredIdentifier(actorUserId, 'actorUserId'),
            isRetired: isRetired,
          ),
        );
      });
    });
  }

  CollectionReference<Map<String, dynamic>> _documents(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('documents');
  }

  CollectionReference<Map<String, dynamic>> _shares(String workspaceId) {
    return _firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('documentShares');
  }

  static String _token() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static List<WorkspaceDocument> _documentList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final documents = <WorkspaceDocument>[];

    for (final entry in snapshot.docs) {
      try {
        documents.add(FirestoreDocumentMapper.fromDocument(entry));
      } on FormatException {
        continue;
      }
    }

    return List.unmodifiable(documents);
  }

  static List<DocumentShare> _shareList(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final shares = <DocumentShare>[];

    for (final entry in snapshot.docs) {
      try {
        shares.add(FirestoreDocumentMapper.shareFromDocument(entry));
      } on FormatException {
        continue;
      }
    }

    return List.unmodifiable(shares);
  }

  static String _requiredIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid document identifier: $field.');
    }

    return normalized;
  }

  static Stream<T> _watch<T>(Stream<T> Function() build) {
    try {
      return build().handleError((Object error) => throw _documentError(error));
    } on Object catch (error) {
      return Stream.error(_documentError(error));
    }
  }

  static Future<T> _execute<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on Object catch (error) {
      throw _documentError(error);
    }
  }

  static Object _documentError(Object error) {
    if (error is DocumentFailure) {
      return error;
    }

    if (error is FormatException) {
      return const DocumentFailure(DocumentFailureCode.invalidData);
    }

    if (error is FirebaseException) {
      return DocumentFailure(switch (error.code) {
        'permission-denied' ||
        'unauthorized' => DocumentFailureCode.permissionDenied,
        'unavailable' ||
        'deadline-exceeded' ||
        'network-request-failed' ||
        'retry-limit-exceeded' => DocumentFailureCode.networkUnavailable,
        'not-found' || 'object-not-found' => DocumentFailureCode.notFound,
        _ => DocumentFailureCode.unknown,
      });
    }

    return const DocumentFailure(DocumentFailureCode.unknown);
  }
}
