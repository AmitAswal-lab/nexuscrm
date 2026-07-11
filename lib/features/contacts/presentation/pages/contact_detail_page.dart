import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_actions/contact_actions_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

class ContactDetailPage extends StatelessWidget {
  const ContactDetailPage({
    required this.isSalesView,
    required this.onEdit,
    required this.onAddFollowUp,
    required this.workspaceId,
    required this.taskAccessScope,
    required this.taskRepository,
    super.key,
  });

  final bool isSalesView;
  final VoidCallback onEdit;
  final VoidCallback onAddFollowUp;
  final String workspaceId;
  final TaskAccessScope taskAccessScope;
  final TaskRepository taskRepository;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactDetailCubit>().state;

    return BlocListener<ContactActionsCubit, ContactActionsState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, actionState) {
        switch (actionState.status) {
          case ContactActionStatus.conversionSuccess:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lead converted to a client.')),
            );
          case ContactActionStatus.archiveSuccess:
            context.pop();
          case ContactActionStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_actionFailure(actionState.failure))),
            );
          case ContactActionStatus.idle ||
              ContactActionStatus.converting ||
              ContactActionStatus.archiving:
            break;
        }
      },
      child: SafeArea(
        child: switch (state.status) {
          ContactDetailStatus.loading => const _MessageView(
            icon: Icons.sync_outlined,
            message: 'Loading this contact…',
            onRetry: null,
            isLoading: true,
          ),
          ContactDetailStatus.notFound => const _NotFoundView(),
          ContactDetailStatus.failure => _FailureView(failure: state.failure),
          ContactDetailStatus.success => _ContactDetailView(
            contact: state.contact!,
            isSalesView: isSalesView,
            onEdit: onEdit,
            onAddFollowUp: onAddFollowUp,
            workspaceId: workspaceId,
            taskAccessScope: taskAccessScope,
            taskRepository: taskRepository,
          ),
        },
      ),
    );
  }

  static String _actionFailure(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to update this contact.',
      ContactFailureCode.networkUnavailable =>
        'The action failed. Check your connection and try again.',
      ContactFailureCode.conflict =>
        'The contact changed. Refresh and try again.',
      _ => 'The action could not be completed right now.',
    };
  }
}

class _ContactDetailView extends StatelessWidget {
  const _ContactDetailView({
    required this.contact,
    required this.isSalesView,
    required this.onEdit,
    required this.onAddFollowUp,
    required this.workspaceId,
    required this.taskAccessScope,
    required this.taskRepository,
  });

  final CrmContact contact;
  final bool isSalesView;
  final VoidCallback onEdit;
  final VoidCallback onAddFollowUp;
  final String workspaceId;
  final TaskAccessScope taskAccessScope;
  final TaskRepository taskRepository;

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
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
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
              const SizedBox(height: 16),
              _ContactActions(contact: contact, onAddFollowUp: onAddFollowUp),
              const SizedBox(height: 16),
              _FollowUpHistory(
                repository: taskRepository,
                workspaceId: workspaceId,
                contactId: contact.id,
                accessScope: taskAccessScope,
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

class _FollowUpHistory extends StatelessWidget {
  const _FollowUpHistory({
    required this.repository,
    required this.workspaceId,
    required this.contactId,
    required this.accessScope,
  });
  final TaskRepository repository;
  final String workspaceId, contactId;
  final TaskAccessScope accessScope;
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CrmTask>>(
      stream: repository.watchContactTasks(
        workspaceId: workspaceId,
        contactId: contactId,
        accessScope: accessScope,
      ),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <CrmTask>[];
        return _DetailSection(
          title: 'Follow-up history',
          children: [
            if (snapshot.connectionState == ConnectionState.waiting &&
                tasks.isEmpty)
              const LinearProgressIndicator(),
            if (snapshot.hasError)
              const Text('Unable to load follow-up history.'),
            if (!snapshot.hasError &&
                tasks.isEmpty &&
                snapshot.connectionState != ConnectionState.waiting)
              const Text('No tasks are linked to this contact yet.'),
            for (final task in tasks.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  task.isCompleted
                      ? Icons.check_circle_outline
                      : Icons.pending_actions_outlined,
                ),
                title: Text(task.title),
                subtitle: Text(
                  task.isCompleted ? 'Completed' : 'Due ${task.dueOn}',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({required this.contact, required this.onAddFollowUp});

  final CrmContact contact;
  final VoidCallback onAddFollowUp;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactActionsCubit>().state;

    return _DetailSection(
      title: 'Actions',
      children: [
        FilledButton.icon(
          onPressed: state.isBusy ? null : onAddFollowUp,
          icon: const Icon(Icons.add_task_outlined),
          label: const Text('Add follow-up'),
        ),
        const SizedBox(height: 10),
        if (contact is Lead)
          FilledButton.tonalIcon(
            onPressed: state.isBusy ? null : () => _confirmConversion(context),
            icon: const Icon(Icons.handshake_outlined),
            label: Text(
              state.status == ContactActionStatus.converting
                  ? 'Converting…'
                  : 'Convert to client',
            ),
          ),
        if (contact is Lead) const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: state.isBusy ? null : () => _confirmArchive(context),
          icon: const Icon(Icons.archive_outlined),
          label: Text(
            state.status == ContactActionStatus.archiving
                ? 'Archiving…'
                : 'Archive contact',
          ),
        ),
      ],
    );
  }

  Future<void> _confirmConversion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert lead to client?'),
        content: const Text(
          'The same contact record and history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ContactActionsCubit>().convertLead();
    }
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive contact?'),
        content: const Text(
          'The contact will leave active lists but its record will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ContactActionsCubit>().archiveContact();
    }
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
    this.isLoading = false,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(),
              )
            else
              Icon(icon, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (onRetry != null)
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            if (onRetry != null) const SizedBox(height: 8),
            TextButton.icon(
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
