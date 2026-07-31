import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/documents/data/repositories/firestore_document_repository.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';

final class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

void main() {
  const publishUrl = 'https://functions.test/publishDocument';

  late FirebaseFirestore firestore;
  late List<http.Request> sent;

  setUp(() {
    firestore = _MockFirebaseFirestore();
    sent = [];
  });

  FirestoreDocumentRepository build({
    Future<String?> Function()? idToken,
    int statusCode = 201,
    String body = '{"documentId":"document-one"}',
  }) {
    return FirestoreDocumentRepository(
      firestore,
      shareLinkBase: 'https://functions.test/sharedDocument',
      publishUrl: publishUrl,
      idToken: idToken ?? () async => 'token-one',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response(body, statusCode);
      }),
    );
  }

  DocumentUpload fileUpload({
    String title = 'Product brochure',
    String? description,
    Uint8List? bytes,
  }) {
    return DocumentUpload(
      title: title,
      description: description,
      contentType: 'application/pdf',
      bytes: bytes ?? Uint8List.fromList([1, 2, 3, 4]),
    );
  }

  Future<String> upload(
    FirestoreDocumentRepository repository, {
    DocumentUpload? file,
  }) {
    return repository.uploadDocument(
      workspaceId: 'workspace-one',
      actorUserId: 'admin-one',
      upload: file ?? fileUpload(),
    );
  }

  Future<DocumentFailureCode> failureOf(
    FirestoreDocumentRepository repository, {
    DocumentUpload? file,
  }) async {
    try {
      await upload(repository, file: file);
    } on DocumentFailure catch (failure) {
      return failure.code;
    }

    fail('the upload was expected to fail');
  }

  group('uploadDocument', () {
    test('posts the file to the endpoint and returns the new identifier', () async {
      final documentId = await upload(
        build(),
        file: fileUpload(description: 'Latest pricing'),
      );

      expect(documentId, 'document-one');
      expect(sent, hasLength(1));

      final request = sent.single;

      expect(request.method, 'POST');
      expect(request.url.origin + request.url.path, publishUrl);
      expect(request.url.queryParameters, {
        'workspaceId': 'workspace-one',
        'title': 'Product brochure',
        'description': 'Latest pricing',
      });
      expect(request.headers['Authorization'], 'Bearer token-one');
      expect(request.headers['Content-Type'], startsWith('application/pdf'));
      expect(request.bodyBytes, [1, 2, 3, 4]);
    });

    test('omits a blank description', () async {
      await upload(build(), file: fileUpload(description: '   '));

      expect(sent.single.url.queryParameters.containsKey('description'), isFalse);
    });

    test('trims the title before sending it', () async {
      await upload(build(), file: fileUpload(title: '  Price list  '));

      expect(sent.single.url.queryParameters['title'], 'Price list');
    });

    test('reports an expired session and sends nothing when the token is null', () async {
      final code = await failureOf(build(idToken: () async => null));

      expect(code, DocumentFailureCode.sessionExpired);
      expect(sent, isEmpty);
    });

    test('reports an expired session and sends nothing when the token is empty', () async {
      final code = await failureOf(build(idToken: () async => ''));

      expect(code, DocumentFailureCode.sessionExpired);
      expect(sent, isEmpty);
    });

    test('separates a rejected token from a rejected role', () async {
      expect(
        await failureOf(build(statusCode: 401)),
        DocumentFailureCode.sessionExpired,
      );
      expect(
        await failureOf(build(statusCode: 403)),
        DocumentFailureCode.permissionDenied,
      );
    });

    test('maps the remaining endpoint answers', () async {
      expect(
        await failureOf(build(statusCode: 400)),
        DocumentFailureCode.invalidData,
      );
      expect(
        await failureOf(build(statusCode: 413)),
        DocumentFailureCode.tooLarge,
      );
      expect(
        await failureOf(build(statusCode: 503)),
        DocumentFailureCode.networkUnavailable,
      );
      expect(
        await failureOf(build(statusCode: 504)),
        DocumentFailureCode.networkUnavailable,
      );
      expect(
        await failureOf(build(statusCode: 500)),
        DocumentFailureCode.unknown,
      );
    });

    test('reports unknown when a success carries no identifier', () async {
      expect(
        await failureOf(build(body: jsonEncode({'documentId': ''}))),
        DocumentFailureCode.unknown,
      );
      expect(
        await failureOf(build(body: jsonEncode(<String, Object>{}))),
        DocumentFailureCode.unknown,
      );
    });

    test('rejects an empty file without calling the endpoint', () async {
      final code = await failureOf(
        build(),
        file: fileUpload(bytes: Uint8List(0)),
      );

      expect(code, DocumentFailureCode.invalidData);
      expect(sent, isEmpty);
    });

    test('rejects a file over the ceiling without calling the endpoint', () async {
      final code = await failureOf(
        build(),
        file: fileUpload(
          bytes: Uint8List(DocumentUpload.maxSizeBytes + 1),
        ),
      );

      expect(code, DocumentFailureCode.tooLarge);
      expect(sent, isEmpty);
    });

    test('rejects a workspace identifier that is not usable', () async {
      final repository = build();

      await expectLater(
        repository.uploadDocument(
          workspaceId: ' ',
          actorUserId: 'admin-one',
          upload: fileUpload(),
        ),
        throwsA(
          isA<DocumentFailure>().having(
            (failure) => failure.code,
            'code',
            DocumentFailureCode.invalidData,
          ),
        ),
      );
      expect(sent, isEmpty);
    });
  });
}
