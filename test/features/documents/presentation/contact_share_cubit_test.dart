import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';
import 'package:nexuscrm/features/documents/domain/services/share_launcher.dart';
import 'package:nexuscrm/features/documents/presentation/cubit/contact_share/contact_share_cubit.dart';

final class _Documents extends Mock implements DocumentRepository {}

final class _Launcher extends Mock implements ShareLauncher {}

void main() {
  setUpAll(() {
    registerFallbackValue(ShareChannel.whatsApp);
  });

  test('creates a link and hands it to the launcher', () async {
    final documents = _Documents();
    final launcher = _Launcher();
    _stubStreams(documents);
    when(
      () => documents.createShareLink(
        workspaceId: any(named: 'workspaceId'),
        documentId: any(named: 'documentId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) async => 'https://example.test/sharedDocument?token=abc');
    when(
      () => launcher.share(
        channel: any(named: 'channel'),
        recipient: any(named: 'recipient'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async => true);

    final cubit = _cubit(documents, launcher);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.share(
      documentId: 'brochure',
      channel: ShareChannel.whatsApp,
    );

    final captured = verify(
      () => launcher.share(
        channel: ShareChannel.whatsApp,
        recipient: '+919000000000',
        subject: any(named: 'subject'),
        message: captureAny(named: 'message'),
      ),
    ).captured.single as String;

    expect(captured, contains('https://example.test/sharedDocument?token=abc'));
    expect(captured, contains('Asha Lead'));
    expect(cubit.state.outcome, ContactShareOutcome.sent);
  });

  test('refuses to share when the contact has no number', () async {
    final documents = _Documents();
    final launcher = _Launcher();
    _stubStreams(documents);

    final cubit = _cubit(documents, launcher, phone: null);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.share(
      documentId: 'brochure',
      channel: ShareChannel.whatsApp,
    );

    expect(cubit.state.outcome, ContactShareOutcome.missingRecipient);
    verifyNever(
      () => documents.createShareLink(
        workspaceId: any(named: 'workspaceId'),
        documentId: any(named: 'documentId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        channel: any(named: 'channel'),
      ),
    );
  });

  test('reports a withdrawn document without launching anything', () async {
    final documents = _Documents();
    final launcher = _Launcher();
    _stubStreams(documents);
    when(
      () => documents.createShareLink(
        workspaceId: any(named: 'workspaceId'),
        documentId: any(named: 'documentId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        channel: any(named: 'channel'),
      ),
    ).thenThrow(const DocumentFailure(DocumentFailureCode.conflict));

    final cubit = _cubit(documents, launcher);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    await cubit.share(
      documentId: 'brochure',
      channel: ShareChannel.whatsApp,
    );

    expect(cubit.state.outcome, ContactShareOutcome.failed);
    expect(
      cubit.state.failure,
      const DocumentFailure(DocumentFailureCode.conflict),
    );
    verifyNever(
      () => launcher.share(
        channel: any(named: 'channel'),
        recipient: any(named: 'recipient'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
      ),
    );
  });
}

void _stubStreams(DocumentRepository documents) {
  when(
    () => documents.watchDocuments(
      workspaceId: any(named: 'workspaceId'),
      includeRetired: any(named: 'includeRetired'),
    ),
  ).thenAnswer((_) => Stream.value(<WorkspaceDocument>[_document]));
  when(
    () => documents.watchContactShares(
      workspaceId: any(named: 'workspaceId'),
      contactId: any(named: 'contactId'),
    ),
  ).thenAnswer((_) => Stream.value(const <DocumentShare>[]));
}

ContactShareCubit _cubit(
  DocumentRepository documents,
  ShareLauncher launcher, {
  String? phone = '+919000000000',
}) {
  return ContactShareCubit(
    documentRepository: documents,
    shareLauncher: launcher,
    workspaceId: 'workspace-one',
    actorUserId: 'sales-user',
    contact: Lead(
      id: 'lead-one',
      workspaceId: 'workspace-one',
      fullName: 'Asha Lead',
      companyName: null,
      email: 'asha@example.com',
      phone: phone,
      notes: null,
      ownerId: 'sales-user',
      stage: LeadStage.qualified,
      isArchived: false,
      createdByUserId: 'sales-user',
      updatedByUserId: 'sales-user',
      createdAt: _time,
      updatedAt: _time,
    ),
  );
}

final _time = DateTime.utc(2026);

final _document = WorkspaceDocument(
  id: 'brochure',
  workspaceId: 'workspace-one',
  title: 'Product brochure',
  description: null,
  storagePath: 'workspaces/workspace-one/documents/brochure',
  contentType: 'application/pdf',
  sizeBytes: 2048,
  isRetired: false,
  uploadedByUserId: 'admin-user',
  updatedByUserId: 'admin-user',
  createdAt: _time,
  updatedAt: _time,
);
