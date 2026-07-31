import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';
import 'package:nexuscrm/features/documents/domain/services/share_launcher.dart';

part 'contact_share_state.dart';

final class ContactShareCubit extends Cubit<ContactShareState> {
  ContactShareCubit({
    required DocumentRepository documentRepository,
    required ShareLauncher shareLauncher,
    required String workspaceId,
    required String actorUserId,
    required CrmContact contact,
    required bool seesEveryShare,
  }) : this._(
         documentRepository,
         shareLauncher,
         workspaceId,
         actorUserId,
         contact,
         seesEveryShare,
       );

  ContactShareCubit._(
    this._documentRepository,
    this._shareLauncher,
    this._workspaceId,
    this._actorUserId,
    this._contact,
    this._seesEveryShare,
  ) : super(const ContactShareState()) {
    unawaited(load());
  }

  final DocumentRepository _documentRepository;
  final ShareLauncher _shareLauncher;
  final String _workspaceId;
  final String _actorUserId;
  final CrmContact _contact;
  final bool _seesEveryShare;

  StreamSubscription<List<WorkspaceDocument>>? _documents;
  StreamSubscription<List<DocumentShare>>? _shares;

  CrmContact get contact => _contact;

  Future<void> load() async {
    unawaited(_documents?.cancel());
    unawaited(_shares?.cancel());

    if (isClosed) return;

    emit(state.copyWith(status: ContactShareStatus.loading));

    _documents = _documentRepository
        .watchDocuments(workspaceId: _workspaceId)
        .listen(
          (value) => _emit(
            state.copyWith(
              status: ContactShareStatus.ready,
              documents: value,
            ),
          ),
          onError: _onError,
        );

    _shares = _documentRepository
        .watchContactShares(
          workspaceId: _workspaceId,
          contactId: _contact.id,
          sharedByUserId: _seesEveryShare ? null : _actorUserId,
        )
        .listen(
          (value) => _emit(state.copyWith(shares: value)),
          onError: _onError,
        );
  }

  Future<void> share({
    required String documentId,
    required ShareChannel channel,
  }) async {
    if (state.isSending) return;

    final recipient = channel == ShareChannel.whatsApp
        ? _contact.phone
        : _contact.email;

    if (recipient == null || recipient.trim().isEmpty) {
      _emit(state.copyWith(outcome: ContactShareOutcome.missingRecipient));
      return;
    }

    _emit(
      state.copyWith(
        sendingDocumentId: documentId,
        outcome: ContactShareOutcome.none,
      ),
    );

    try {
      final link = await _documentRepository.createShareLink(
        workspaceId: _workspaceId,
        documentId: documentId,
        contactId: _contact.id,
        actorUserId: _actorUserId,
        channel: channel,
      );
      final title = state.documents
          .where((document) => document.id == documentId)
          .map((document) => document.title)
          .firstOrNull;
      final launched = await _shareLauncher.share(
        channel: channel,
        recipient: recipient,
        subject: title ?? 'Document from Nexus CRM',
        message: shareMessage(
          contactName: _contact.fullName,
          documentTitle: title ?? 'document',
          link: link,
        ),
      );

      _emit(
        state.copyWith(
          clearSending: true,
          outcome: launched
              ? ContactShareOutcome.sent
              : ContactShareOutcome.launchFailed,
        ),
      );
    } on Object catch (error) {
      _emit(
        state.copyWith(
          clearSending: true,
          outcome: ContactShareOutcome.failed,
          failure: error is DocumentFailure
              ? error
              : const DocumentFailure(DocumentFailureCode.unknown),
        ),
      );
    }
  }

  Future<void> revoke(String shareId) async {
    try {
      await _documentRepository.revokeShare(
        workspaceId: _workspaceId,
        shareId: shareId,
        actorUserId: _actorUserId,
      );
    } on Object catch (error) {
      _emit(
        state.copyWith(
          outcome: ContactShareOutcome.failed,
          failure: error is DocumentFailure
              ? error
              : const DocumentFailure(DocumentFailureCode.unknown),
        ),
      );
    }
  }

  void acknowledgeOutcome() {
    if (state.outcome != ContactShareOutcome.none) {
      _emit(state.copyWith(outcome: ContactShareOutcome.none));
    }
  }

  void _emit(ContactShareState next) {
    if (!isClosed) emit(next);
  }

  void _onError(Object error, StackTrace stackTrace) {
    _emit(
      state.copyWith(
        status: ContactShareStatus.failure,
        failure: error is DocumentFailure
            ? error
            : const DocumentFailure(DocumentFailureCode.unknown),
      ),
    );
  }

  @override
  Future<void> close() async {
    unawaited(_documents?.cancel());
    unawaited(_shares?.cancel());
    return super.close();
  }
}
