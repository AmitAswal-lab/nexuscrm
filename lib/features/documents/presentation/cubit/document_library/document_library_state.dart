part of 'document_library_cubit.dart';

enum DocumentLibraryStatus { loading, success, failure }

final class DocumentLibraryState extends Equatable {
  const DocumentLibraryState({
    this.status = DocumentLibraryStatus.loading,
    this.documents = const <WorkspaceDocument>[],
    this.isUploading = false,
    this.busyDocumentId,
    this.failure,
    this.actionFailure,
  });

  final DocumentLibraryStatus status;
  final List<WorkspaceDocument> documents;
  final bool isUploading;
  final String? busyDocumentId;
  final DocumentFailure? failure;
  final DocumentFailure? actionFailure;

  bool get isBusy => isUploading || busyDocumentId != null;

  List<WorkspaceDocument> get published =>
      documents.where((document) => !document.isRetired).toList(growable: false);

  List<WorkspaceDocument> get retired =>
      documents.where((document) => document.isRetired).toList(growable: false);

  DocumentLibraryState copyWith({
    DocumentLibraryStatus? status,
    List<WorkspaceDocument>? documents,
    bool? isUploading,
    String? busyDocumentId,
    DocumentFailure? failure,
    DocumentFailure? actionFailure,
    bool clearBusyDocument = false,
    bool clearActionFailure = false,
  }) => DocumentLibraryState(
    status: status ?? this.status,
    documents: documents ?? this.documents,
    isUploading: isUploading ?? this.isUploading,
    busyDocumentId: clearBusyDocument
        ? null
        : busyDocumentId ?? this.busyDocumentId,
    failure: failure ?? this.failure,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
  );

  @override
  List<Object?> get props => [
    status,
    documents,
    isUploading,
    busyDocumentId,
    failure,
    actionFailure,
  ];
}
