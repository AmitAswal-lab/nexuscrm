import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/archived_contacts/archived_contacts_cubit.dart';

class ArchivedContactsPage extends StatelessWidget {
  const ArchivedContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocListener<ArchivedContactsCubit, ArchivedContactsState>(
        listenWhen: (previous, current) =>
            previous.actionFailure != current.actionFailure,
        listener: (context, state) {
          if (state.actionFailure != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_restoreMessage(state.actionFailure))),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
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
                          'Archived contacts',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Restoring a contact returns it to your active lists. '
                    'Archived contacts cannot be edited.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Expanded(child: _ArchivedContactsBody()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _restoreMessage(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to restore this contact.',
      ContactFailureCode.networkUnavailable =>
        'Restore is unavailable. Check your connection and try again.',
      ContactFailureCode.notFound => 'This contact no longer exists.',
      _ => 'Unable to restore this contact. Please try again.',
    };
  }
}

class _ArchivedContactsBody extends StatelessWidget {
  const _ArchivedContactsBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ArchivedContactsCubit>().state;

    if (state.status == ArchivedContactsStatus.loading &&
        state.contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ArchivedContactsStatus.failure &&
        state.contacts.isEmpty) {
      return _FailureView(failure: state.failure);
    }

    if (state.contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No archived contacts.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: state.contacts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ArchivedContactCard(
        contact: state.contacts[index],
        isRestoring:
            state.restoringContactId == state.contacts[index].id,
        isBusy: state.restoringContactId != null,
      ),
    );
  }
}

class _ArchivedContactCard extends StatelessWidget {
  const _ArchivedContactCard({
    required this.contact,
    required this.isRestoring,
    required this.isBusy,
  });

  final CrmContact contact;
  final bool isRestoring;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              child: const Icon(Icons.archive_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.fullName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _subtitle(contact),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: isBusy
                  ? null
                  : () =>
                        context.read<ArchivedContactsCubit>().restore(
                          contact.id,
                        ),
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(isRestoring ? 'Restoring…' : 'Restore'),
            ),
          ],
        ),
      ),
    );
  }

  static String _subtitle(CrmContact contact) {
    final kind = contact is Lead ? 'Lead' : 'Client';
    final detail = contact.companyName ?? contact.email ?? contact.phone;

    return detail == null ? kind : '$kind · $detail';
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final ContactFailure? failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _message(failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: context.read<ArchivedContactsCubit>().load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to view archived contacts.',
      ContactFailureCode.networkUnavailable =>
        'Archived contacts are unavailable. Check your connection and try '
            'again.',
      _ => 'Unable to load archived contacts right now.',
    };
  }
}
