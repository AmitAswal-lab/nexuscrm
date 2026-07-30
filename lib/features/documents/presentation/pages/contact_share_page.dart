import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/documents/domain/entities/document_share.dart';
import 'package:nexuscrm/features/documents/domain/entities/workspace_document.dart';
import 'package:nexuscrm/features/documents/domain/failures/document_failure.dart';
import 'package:nexuscrm/features/documents/presentation/cubit/contact_share/contact_share_cubit.dart';

class ContactSharePage extends StatelessWidget {
  const ContactSharePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocListener<ContactShareCubit, ContactShareState>(
        listenWhen: (previous, current) => previous.outcome != current.outcome,
        listener: (context, state) {
          if (state.outcome == ContactShareOutcome.none) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_outcomeMessage(state))),
          );
          context.read<ContactShareCubit>().acknowledgeOutcome();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: const _ShareBody(),
            ),
          ),
        ),
      ),
    );
  }

  static String _outcomeMessage(ContactShareState state) {
    return switch (state.outcome) {
      ContactShareOutcome.sent => 'Link ready. Finish sending in the app that '
          'just opened.',
      ContactShareOutcome.launchFailed =>
        'Could not open that app on this device.',
      ContactShareOutcome.missingRecipient =>
        'This contact has no number or address for that option.',
      ContactShareOutcome.failed => switch (state.failure?.code) {
        DocumentFailureCode.permissionDenied =>
          'You do not have permission to share with this contact.',
        DocumentFailureCode.networkUnavailable =>
          'Sharing is unavailable. Check your connection and try again.',
        DocumentFailureCode.conflict =>
          'That document has been withdrawn and cannot be shared.',
        _ => 'Unable to prepare that link. Please try again.',
      },
      ContactShareOutcome.none => '',
    };
  }
}

class _ShareBody extends StatelessWidget {
  const _ShareBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ContactShareCubit>();
    final state = cubit.state;
    final contact = cubit.contact;

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
                'Send a document',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'A link is sent to ${contact.fullName}. The file stays on the '
          'workspace and the link expires.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: switch (state.status) {
            ContactShareStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ContactShareStatus.failure => const Center(
              child: Text('Unable to load documents right now.'),
            ),
            ContactShareStatus.ready when state.documents.isEmpty =>
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No documents have been published yet. An administrator '
                    'adds them from the document library.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ContactShareStatus.ready => ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final document in state.documents)
                  _DocumentCard(
                    document: document,
                    isSending: state.sendingDocumentId == document.id,
                    isBusy: state.isSending,
                    canWhatsApp: _hasValue(contact.phone),
                    canEmail: _hasValue(contact.email),
                  ),
                if (state.shares.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Sent links',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final share in state.shares)
                    _ShareRow(share: share),
                ],
              ],
            ),
          },
        ),
      ],
    );
  }

  static bool _hasValue(String? value) =>
      value != null && value.trim().isNotEmpty;
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.isSending,
    required this.isBusy,
    required this.canWhatsApp,
    required this.canEmail,
  });

  final WorkspaceDocument document;
  final bool isSending;
  final bool isBusy;
  final bool canWhatsApp;
  final bool canEmail;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ContactShareCubit>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (document.description != null) ...[
              const SizedBox(height: 4),
              Text(
                document.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _sizeLabel(document.sizeBytes),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isBusy || !canWhatsApp
                      ? null
                      : () => cubit.share(
                          documentId: document.id,
                          channel: ShareChannel.whatsApp,
                        ),
                  icon: const Icon(Icons.chat_outlined),
                  label: Text(isSending ? 'Preparing…' : 'WhatsApp'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy || !canEmail
                      ? null
                      : () => cubit.share(
                          documentId: document.id,
                          channel: ShareChannel.email,
                        ),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Email'),
                ),
              ],
            ),
          ],
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

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share});

  final DocumentShare share;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final active = share.isActiveAt(now);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        active ? Icons.link : Icons.link_off,
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(share.documentTitle),
      subtitle: Text(_statusLabel(share, now)),
      trailing: active
          ? TextButton(
              onPressed: () =>
                  context.read<ContactShareCubit>().revoke(share.id),
              child: const Text('Revoke'),
            )
          : null,
    );
  }

  static String _statusLabel(DocumentShare share, DateTime now) {
    final channel = share.channel == ShareChannel.whatsApp
        ? 'WhatsApp'
        : 'Email';
    final opens = share.openCount == 0
        ? 'not opened yet'
        : share.openCount == 1
        ? 'opened once'
        : 'opened ${share.openCount} times';

    if (share.isRevoked) return '$channel · revoked';
    if (share.isExpiredAt(now)) return '$channel · expired · $opens';

    return '$channel · $opens';
  }
}
