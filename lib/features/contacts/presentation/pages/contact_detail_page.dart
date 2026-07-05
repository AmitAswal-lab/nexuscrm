import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({required this.isSalesView, super.key});

  final bool isSalesView;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactDetailCubit>().state;

    return SafeArea(
      child: switch (state.status) {
        ContactDetailStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ContactDetailStatus.notFound => const _NotFoundView(),
        ContactDetailStatus.failure => _FailureView(failure: state.failure),
        ContactDetailStatus.success => _ContactDetailView(
          contact: state.contact!,
          isSalesView: isSalesView,
        ),
      },
    );
  }
}

class _ContactDetailView extends StatelessWidget {
  const _ContactDetailView({required this.contact, required this.isSalesView});

  final CrmContact contact;
  final bool isSalesView;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.fullName,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        _StatusChip(contact: contact),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DetailSection(
                title: 'Contact',
                children: [
                  _DetailRow(
                    icon: Icons.business_outlined,
                    label: 'Company',
                    value: contact.companyName ?? 'Not provided',
                  ),
                  _DetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: contact.email ?? 'Not provided',
                  ),
                  _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: contact.phone ?? 'Not provided',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Assignment',
                children: [
                  _DetailRow(
                    icon: Icons.assignment_ind_outlined,
                    label: 'Owner',
                    value: _ownerLabel(contact.ownerId),
                  ),
                  _DetailRow(
                    icon: Icons.update_outlined,
                    label: 'Last updated',
                    value: _formatDate(contact.updatedAt),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Notes',
                children: [
                  Text(
                    contact.notes ?? 'No notes have been added.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              if (contact case ClientContact(:final convertedAt)) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  title: 'Client history',
                  children: [
                    _DetailRow(
                      icon: Icons.handshake_outlined,
                      label: 'Converted',
                      value: _formatDate(convertedAt),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _ownerLabel(String? ownerId) {
    if (ownerId == null) {
      return 'Unassigned';
    }

    return isSalesView ? 'Assigned to you' : 'Assigned sales representative';
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = value.toLocal();

    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.contact});

  final CrmContact contact;

  @override
  Widget build(BuildContext context) {
    final label = switch (contact) {
      Lead(:final stage) => switch (stage) {
        LeadStage.newLead => 'Lead · New',
        LeadStage.contacted => 'Lead · Contacted',
        LeadStage.qualified => 'Lead · Qualified',
        LeadStage.proposal => 'Lead · Proposal',
        LeadStage.lost => 'Lead · Lost',
      },
      ClientContact() => 'Client',
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(label: Text(label)),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return _MessageView(
      icon: Icons.person_off_outlined,
      message: 'This contact is no longer available.',
      onRetry: null,
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final ContactFailure? failure;

  @override
  Widget build(BuildContext context) {
    final message = switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to view this contact.',
      ContactFailureCode.networkUnavailable =>
        'The contact is unavailable. Check your connection and try again.',
      _ => 'Unable to load this contact right now.',
    };

    return _MessageView(
      icon: Icons.cloud_off_outlined,
      message: message,
      onRetry: context.read<ContactDetailCubit>().load,
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (onRetry != null)
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to contacts'),
              ),
          ],
        ),
      ),
    );
  }
}
