import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_list/contact_list_cubit.dart';

class ContactListPage extends StatelessWidget {
  const ContactListPage({
    required this.title,
    required this.description,
    required this.onCreateLead,
    super.key,
  });

  final String title;
  final String description;
  final VoidCallback onCreateLead;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onCreateLead,
                      icon: const Icon(Icons.add),
                      label: const Text('New lead'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const _ContactFilter(),
                const SizedBox(height: 16),
                const Expanded(child: _ContactListBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactFilter extends StatelessWidget {
  const _ContactFilter();

  @override
  Widget build(BuildContext context) {
    final selected = context.select<ContactListCubit, ContactListFilter>(
      (cubit) => cubit.state.filter,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ContactListFilter>(
        segments: const [
          ButtonSegment(value: ContactListFilter.all, label: Text('All')),
          ButtonSegment(value: ContactListFilter.leads, label: Text('Leads')),
          ButtonSegment(
            value: ContactListFilter.clients,
            label: Text('Clients'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          context.read<ContactListCubit>().selectFilter(selection.single);
        },
      ),
    );
  }
}

class _ContactListBody extends StatelessWidget {
  const _ContactListBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactListCubit>().state;

    return switch (state.status) {
      ContactListStatus.loading when state.contacts.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      ContactListStatus.failure when state.contacts.isEmpty => _FailureView(
        failure: state.failure,
      ),
      _ => _ContactResults(state: state),
    };
  }
}

class _ContactResults extends StatelessWidget {
  const _ContactResults({required this.state});

  final ContactListState state;

  @override
  Widget build(BuildContext context) {
    final contacts = state.visibleContacts;

    if (contacts.isEmpty) {
      return _EmptyView(filter: state.filter);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: contacts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _ContactCard(contact: contacts[index]),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});

  final CrmContact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = contact.companyName ?? _contactMethod(contact);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              child: Icon(
                contact.kind == ContactKind.lead
                    ? Icons.person_search_outlined
                    : Icons.person_outline,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.fullName, style: theme.textTheme.titleMedium),
                  if (secondaryText != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (contact.companyName != null &&
                      _contactMethod(contact) != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      _contactMethod(contact)!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ContactStatus(contact: contact),
          ],
        ),
      ),
    );
  }

  static String? _contactMethod(CrmContact contact) {
    return contact.email ?? contact.phone;
  }
}

class _ContactStatus extends StatelessWidget {
  const _ContactStatus({required this.contact});

  final CrmContact contact;

  @override
  Widget build(BuildContext context) {
    final label = switch (contact) {
      Lead(:final stage) => _stageLabel(stage),
      ClientContact() => 'Client',
    };

    return Chip(visualDensity: VisualDensity.compact, label: Text(label));
  }

  static String _stageLabel(LeadStage stage) {
    return switch (stage) {
      LeadStage.newLead => 'New',
      LeadStage.contacted => 'Contacted',
      LeadStage.qualified => 'Qualified',
      LeadStage.proposal => 'Proposal',
      LeadStage.lost => 'Lost',
    };
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});

  final ContactListFilter filter;

  @override
  Widget build(BuildContext context) {
    final message = switch (filter) {
      ContactListFilter.all => 'No leads or clients yet.',
      ContactListFilter.leads => 'No leads found.',
      ContactListFilter.clients => 'No clients found.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Lead creation will be added in the next workflow checkpoint.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
              onPressed: context.read<ContactListCubit>().load,
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
        'You do not have permission to view these contacts.',
      ContactFailureCode.networkUnavailable =>
        'Contacts are unavailable. Check your connection and try again.',
      _ => 'Unable to load contacts right now.',
    };
  }
}
