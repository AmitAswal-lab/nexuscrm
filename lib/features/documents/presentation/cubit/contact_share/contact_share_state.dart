part of 'contact_share_cubit.dart';

enum ContactShareStatus { loading, ready, failure }

enum ContactShareOutcome {
  none,
  sent,
  launchFailed,
  missingRecipient,
  failed,
}

final class ContactShareState extends Equatable {
  const ContactShareState({
    this.status = ContactShareStatus.loading,
    this.documents = const <WorkspaceDocument>[],
    this.shares = const <DocumentShare>[],
    this.sendingDocumentId,
    this.outcome = ContactShareOutcome.none,
    this.failure,
  });

  final ContactShareStatus status;
  final List<WorkspaceDocument> documents;
  final List<DocumentShare> shares;
  final String? sendingDocumentId;
  final ContactShareOutcome outcome;
  final DocumentFailure? failure;

  bool get isSending => sendingDocumentId != null;

  ContactShareState copyWith({
    ContactShareStatus? status,
    List<WorkspaceDocument>? documents,
    List<DocumentShare>? shares,
    String? sendingDocumentId,
    ContactShareOutcome? outcome,
    DocumentFailure? failure,
    bool clearSending = false,
  }) => ContactShareState(
    status: status ?? this.status,
    documents: documents ?? this.documents,
    shares: shares ?? this.shares,
    sendingDocumentId: clearSending
        ? null
        : sendingDocumentId ?? this.sendingDocumentId,
    outcome: outcome ?? this.outcome,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [
    status,
    documents,
    shares,
    sendingDocumentId,
    outcome,
    failure,
  ];
}
