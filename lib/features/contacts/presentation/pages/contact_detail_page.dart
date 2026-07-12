import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/contacts/data/services/url_launcher_phone_dialer.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/services/phone_dialer.dart';
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
    required this.onLogCallNote,
    required this.onViewAllActivity,
    required this.workspaceId,
    required this.taskAccessScope,
    required this.taskRepository,
    required this.activityRepository,
    required this.salesAssigneeRepository,
    this.phoneDialer = const UrlLauncherPhoneDialer(),
    super.key,
  });

  final bool isSalesView;
  final VoidCallback onEdit;
  final VoidCallback onAddFollowUp;
  final VoidCallback onLogCallNote;
  final VoidCallback onViewAllActivity;
  final String workspaceId;
  final TaskAccessScope taskAccessScope;
  final TaskRepository taskRepository;
  final ActivityRepository activityRepository;
  final SalesAssigneeRepository salesAssigneeRepository;
  final PhoneDialer phoneDialer;

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
            onLogCallNote: onLogCallNote,
            onViewAllActivity: onViewAllActivity,
            workspaceId: workspaceId,
            taskAccessScope: taskAccessScope,
            taskRepository: taskRepository,
            activityRepository: activityRepository,
            salesAssigneeRepository: salesAssigneeRepository,
            phoneDialer: phoneDialer,
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
    required this.onLogCallNote,
    required this.onViewAllActivity,
    required this.workspaceId,
    required this.taskAccessScope,
    required this.taskRepository,
    required this.activityRepository,
    required this.salesAssigneeRepository,
    required this.phoneDialer,
  });

  final CrmContact contact;
  final bool isSalesView;
  final VoidCallback onEdit;
  final VoidCallback onAddFollowUp;
  final VoidCallback onLogCallNote;
  final VoidCallback onViewAllActivity;
  final String workspaceId;
  final TaskAccessScope taskAccessScope;
  final TaskRepository taskRepository;
  final ActivityRepository activityRepository;
  final SalesAssigneeRepository salesAssigneeRepository;
  final PhoneDialer phoneDialer;

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
                  _OwnerRow(
                    ownerId: contact.ownerId,
                    workspaceId: workspaceId,
                    salesAssigneeRepository: salesAssigneeRepository,
                    isSalesView: isSalesView,
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
              _ContactActions(
                contact: contact,
                onAddFollowUp: onAddFollowUp,
                onLogCallNote: onLogCallNote,
                phoneDialer: phoneDialer,
              ),
              const SizedBox(height: 16),
              ContactActivityTimeline(
                title: 'Recent activity',
                maxEntries: 3,
                workspaceId: workspaceId,
                contactId: contact.id,
                activityRepository: activityRepository,
                taskRepository: taskRepository,
                taskAccessScope: taskAccessScope,
                salesAssigneeRepository: salesAssigneeRepository,
                isSalesView: isSalesView,
                onViewAll: onViewAllActivity,
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

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({
    required this.ownerId,
    required this.workspaceId,
    required this.salesAssigneeRepository,
    required this.isSalesView,
  });

  final String? ownerId;
  final String workspaceId;
  final SalesAssigneeRepository salesAssigneeRepository;
  final bool isSalesView;

  @override
  Widget build(BuildContext context) {
    if (ownerId == null) {
      return const _DetailRow(
        icon: Icons.assignment_ind_outlined,
        label: 'Owner',
        value: 'Unassigned',
      );
    }
    if (isSalesView) {
      return const _DetailRow(
        icon: Icons.assignment_ind_outlined,
        label: 'Owner',
        value: 'Assigned to you',
      );
    }

    return StreamBuilder<List<SalesAssignee>>(
      stream: salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: workspaceId,
      ),
      builder: (context, snapshot) {
        SalesAssignee? owner;
        for (final assignee in snapshot.data ?? const <SalesAssignee>[]) {
          if (assignee.userId == ownerId) {
            owner = assignee;
            break;
          }
        }
        return _DetailRow(
          icon: Icons.assignment_ind_outlined,
          label: 'Owner',
          value: owner?.displayName ?? 'Assigned sales representative',
        );
      },
    );
  }
}

class ContactActivityTimeline extends StatelessWidget {
  const ContactActivityTimeline({
    required this.title,
    required this.maxEntries,
    required this.activityRepository,
    required this.taskRepository,
    required this.workspaceId,
    required this.contactId,
    required this.taskAccessScope,
    required this.salesAssigneeRepository,
    required this.isSalesView,
    this.onViewAll,
    super.key,
  });

  final String title;
  final int? maxEntries;
  final ActivityRepository activityRepository;
  final TaskRepository taskRepository;
  final String workspaceId;
  final String contactId;
  final TaskAccessScope taskAccessScope;
  final SalesAssigneeRepository salesAssigneeRepository;
  final bool isSalesView;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CallNote>>(
      stream: activityRepository.watchCallNotes(
        workspaceId: workspaceId,
        contactId: contactId,
      ),
      builder: (context, notesSnapshot) {
        final notes = notesSnapshot.data ?? const <CallNote>[];

        return StreamBuilder<List<CrmTask>>(
          stream: taskRepository.watchContactTasks(
            workspaceId: workspaceId,
            contactId: contactId,
            accessScope: taskAccessScope,
          ),
          builder: (context, tasksSnapshot) {
            return StreamBuilder<List<SalesAssignee>>(
              stream: isSalesView
                  ? Stream.value(const <SalesAssignee>[])
                  : salesAssigneeRepository.watchActiveSalesAssignees(
                      workspaceId: workspaceId,
                    ),
              builder: (context, assigneesSnapshot) {
                final names = {
                  for (final assignee
                      in assigneesSnapshot.data ?? const <SalesAssignee>[])
                    assignee.userId: assignee.displayName,
                };
                final entries = <_ActivityEntry>[
                  ...notes.map((note) => _ActivityEntry.call(note)),
                  ...(tasksSnapshot.data ?? const <CrmTask>[]).map(
                    _ActivityEntry.followUp,
                  ),
                ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final visibleEntries = maxEntries == null
                    ? entries
                    : entries.take(maxEntries!).toList();
                return _DetailSection(
                  title: title,
                  children: [
                    if (notesSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        entries.isEmpty)
                      const LinearProgressIndicator(),
                    if (notesSnapshot.hasError || tasksSnapshot.hasError)
                      const Text('Unable to load activity.'),
                    if (!notesSnapshot.hasError &&
                        !tasksSnapshot.hasError &&
                        entries.isEmpty &&
                        notesSnapshot.connectionState !=
                            ConnectionState.waiting)
                      const Text('No activity has been logged yet.'),
                    for (final entry in visibleEntries)
                      _ActivityTile(
                        entry: entry,
                        userNames: names,
                        isSalesView: isSalesView,
                      ),
                    if (onViewAll != null && entries.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onViewAll,
                          icon: const Icon(Icons.timeline_outlined),
                          label: const Text('View all activity'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

final class _ActivityEntry {
  _ActivityEntry.call(CallNote note)
    : callNote = note,
      task = null,
      createdAt = note.createdAt;

  _ActivityEntry.followUp(CrmTask followUp)
    : callNote = null,
      task = followUp,
      createdAt = followUp.createdAt;

  final CallNote? callNote;
  final CrmTask? task;
  final DateTime createdAt;
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.entry,
    required this.userNames,
    required this.isSalesView,
  });

  final _ActivityEntry entry;
  final Map<String, String> userNames;
  final bool isSalesView;

  @override
  Widget build(BuildContext context) {
    final callNote = entry.callNote;
    final task = entry.task;

    if (callNote != null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(_outcomeIcon(callNote.outcome)),
        title: Text(_outcomeLabel(callNote.outcome)),
        subtitle: Text(
          [
            if (callNote.note != null) callNote.note!,
            'Logged by ${_nameFor(callNote.actorUserId)}',
          ].join('\n'),
        ),
        trailing: Text(_formatTimestamp(callNote.createdAt)),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        task!.isCompleted
            ? Icons.check_circle_outline
            : Icons.pending_actions_outlined,
      ),
      title: Text(task.title),
      subtitle: Text(
        'Follow-up • Due ${task.dueOn} • ${task.isCompleted ? 'Completed' : 'Open'}\nAssigned to ${_nameFor(task.assigneeId)}',
      ),
      trailing: Text(_formatTimestamp(task.createdAt)),
    );
  }

  String _nameFor(String userId) {
    if (isSalesView) {
      return 'You';
    }

    return userNames[userId] ?? 'Administrator';
  }

  static IconData _outcomeIcon(CallOutcome outcome) => switch (outcome) {
    CallOutcome.connected => Icons.phone_in_talk_outlined,
    CallOutcome.voicemail => Icons.voicemail_outlined,
    CallOutcome.noAnswer => Icons.phone_missed_outlined,
    CallOutcome.wrongNumber => Icons.phone_disabled_outlined,
    CallOutcome.other => Icons.call_outlined,
  };

  static String _outcomeLabel(CallOutcome outcome) => switch (outcome) {
    CallOutcome.connected => 'Connected',
    CallOutcome.voicemail => 'Left voicemail',
    CallOutcome.noAnswer => 'No answer',
    CallOutcome.wrongNumber => 'Wrong number',
    CallOutcome.other => 'Other call outcome',
  };

  static String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}\n${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({
    required this.contact,
    required this.onAddFollowUp,
    required this.onLogCallNote,
    required this.phoneDialer,
  });

  final CrmContact contact;
  final VoidCallback onAddFollowUp;
  final VoidCallback onLogCallNote;
  final PhoneDialer phoneDialer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactActionsCubit>().state;
    final phoneNumber = normalizeDialablePhoneNumber(contact.phone);

    return _DetailSection(
      title: 'Actions',
      children: [
        FilledButton.icon(
          onPressed: state.isBusy || phoneNumber == null
              ? null
              : () => _placeCall(context, phoneNumber),
          icon: const Icon(Icons.phone_outlined),
          label: Text(
            phoneNumber == null ? 'Phone unavailable' : 'Call contact',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: state.isBusy ? null : onLogCallNote,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Log call note'),
        ),
        const SizedBox(height: 10),
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

  Future<void> _placeCall(BuildContext context, String phoneNumber) async {
    try {
      final launched = await phoneDialer.dial(phoneNumber);

      if (!launched && context.mounted) {
        _showDialerFailure(context);
      }
    } on Object {
      if (context.mounted) {
        _showDialerFailure(context);
      }
    }
  }

  void _showDialerFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to open the phone dialer on this device.'),
      ),
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
