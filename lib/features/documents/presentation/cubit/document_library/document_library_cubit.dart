import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';

part 'document_library_state.dart';

final class DocumentLibraryCubit extends Cubit<DocumentLibraryState> {
  factory DocumentLibraryCubit({
    required DocumentRepository documentRepository,
    required String workspaceId,
    required String actorUserId,
  }) => DocumentLibraryCubit._(documentRepository, workspaceId, actorUserId);

  DocumentLibraryCubit._(
    this._documentRepository,
    this._workspaceId,
    this._actorUserId,
  ) : super(const DocumentLibraryState()) {
    unawaited(load());
  }

  final DocumentRepository _documentRepository;
  final String _workspaceId;
  final String _actorUserId;

  StreamSubscription<List<WorkspaceDocument>>? _subscription;

  Future<void> load() async {
    unawaited(_subscription?.cancel());

    if (isClosed) return;

    emit(state.copyWith(status: DocumentLibraryStatus.loading));

    _subscription = _documentRepository
        .watchDocuments(workspaceId: _workspaceId, includeRetired: true)
        .listen(
          (value) => _emit(
            state.copyWith(
              status: DocumentLibraryStatus.success,
              documents: value,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) => _emit(
            state.copyWith(
              status: DocumentLibraryStatus.failure,
              failure: _failure(error),
            ),
          ),
        );
  }

  Future<void> upload(DocumentUpload upload) async {
    if (state.isBusy) return;

    _emit(state.copyWith(isUploading: true, clearActionFailure: true));

    try {
      await _documentRepository.uploadDocument(
        workspaceId: _workspaceId,
        actorUserId: _actorUserId,
        upload: upload,
      );
      _emit(state.copyWith(isUploading: false));
    } on Object catch (error) {
      _emit(
        state.copyWith(isUploading: false, actionFailure: _failure(error)),
      );
    }
  }

  Future<void> setRetired({
    required String documentId,
    required bool isRetired,
  }) async {
    if (state.isBusy) return;

    _emit(state.copyWith(busyDocumentId: documentId, clearActionFailure: true));

    try {
      if (isRetired) {
        await _documentRepository.retireDocument(
          workspaceId: _workspaceId,
          documentId: documentId,
          actorUserId: _actorUserId,
        );
      } else {
        await _documentRepository.restoreDocument(
          workspaceId: _workspaceId,
          documentId: documentId,
          actorUserId: _actorUserId,
        );
      }
      _emit(state.copyWith(clearBusyDocument: true));
    } on Object catch (error) {
      _emit(
        state.copyWith(
          clearBusyDocument: true,
          actionFailure: _failure(error),
        ),
      );
    }
  }

  void _emit(DocumentLibraryState next) {
    if (!isClosed) emit(next);
  }

  static DocumentFailure _failure(Object error) => error is DocumentFailure
      ? error
      : const DocumentFailure(DocumentFailureCode.unknown);

  @override
  Future<void> close() async {
    unawaited(_subscription?.cancel());
    return super.close();
  }
}
