import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_upload.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/presentation/cubit/document_library/document_library_cubit.dart';

class DocumentLibraryPage extends StatelessWidget {
  const DocumentLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocListener<DocumentLibraryCubit, DocumentLibraryState>(
        listenWhen: (previous, current) =>
            previous.actionFailure != current.actionFailure,
        listener: (context, state) {
          if (state.actionFailure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_failureMessage(state.actionFailure))),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: const _LibraryBody(),
            ),
          ),
        ),
      ),
    );
  }

  static String _failureMessage(DocumentFailure? failure) {
    return switch (failure?.code) {
      DocumentFailureCode.permissionDenied =>
        'Only an administrator can change the document library.',
      DocumentFailureCode.sessionExpired =>
        'Your sign-in has expired. Sign out and back in, then try again.',
      DocumentFailureCode.networkUnavailable =>
        'The library is unavailable. Check your connection and try again.',
      DocumentFailureCode.tooLarge => 'That file is larger than 10 MB.',
      DocumentFailureCode.invalidData => 'That file could not be read.',
      _ => 'Unable to complete that change. Please try again.',
    };
  }
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<DocumentLibraryCubit>();
    final state = cubit.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: context.pop,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Documents',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: state.isBusy
                  ? null
                  : () => _pickAndUpload(context, cubit),
              icon: const Icon(Icons.upload_file),
              label: Text(state.isUploading ? 'Uploading…' : 'Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Representatives can send these to contacts. They can never '
          'download the file itself.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: switch (state.status) {
            DocumentLibraryStatus.loading when state.documents.isEmpty =>
              const Center(child: CircularProgressIndicator()),
            DocumentLibraryStatus.failure when state.documents.isEmpty =>
              const Center(child: Text('Unable to load the document library.')),
            _ when state.documents.isEmpty => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No documents yet. Use Add to publish the first one.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _ => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final document in state.published)
                  _DocumentRow(
                    document: document,
                    isBusy: state.busyDocumentId == document.id,
                    disabled: state.isBusy,
                  ),
                if (state.retired.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Withdrawn',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final document in state.retired)
                    _DocumentRow(
                      document: document,
                      isBusy: state.busyDocumentId == document.id,
                      disabled: state.isBusy,
                    ),
                ],
              ],
            ),
          },
        ),
      ],
    );
  }

  static Future<void> _pickAndUpload(
    BuildContext context,
    DocumentLibraryCubit cubit,
  ) async {
    final file = await openFile();

    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();

    if (!context.mounted) return;

    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _TitleDialog(suggestion: file.name),
    );

    if (title == null || title.trim().isEmpty) {
      return;
    }

    await cubit.upload(
      DocumentUpload(
        title: title.trim(),
        description: null,
        contentType: file.mimeType ?? _contentType(file.name),
        bytes: bytes,
      ),
    );
  }

  static String _contentType(String fileName) {
    final extension = fileName.split('.').lastOrNull;

    return switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
  }
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.suggestion});

  final String suggestion;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.suggestion,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this document'),
      content: TextField(
        controller: _controller,
        maxLength: 120,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Publish'),
        ),
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.isBusy,
    required this.disabled,
  });

  final WorkspaceDocument document;
  final bool isBusy;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          document.isRetired
              ? Icons.visibility_off_outlined
              : Icons.description_outlined,
        ),
        title: Text(document.title),
        subtitle: Text(_sizeLabel(document.sizeBytes)),
        trailing: TextButton(
          onPressed: disabled
              ? null
              : () => context.read<DocumentLibraryCubit>().setRetired(
                  documentId: document.id,
                  isRetired: !document.isRetired,
                ),
          child: Text(
            isBusy
                ? 'Working…'
                : document.isRetired
                ? 'Republish'
                : 'Withdraw',
          ),
        ),
      ),
    );
  }

  static String _sizeLabel(int sizeBytes) {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
