import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/admin/presentation/cubit/activity_overview/activity_overview_cubit.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';

class AdminActivityPage extends StatelessWidget {
  const AdminActivityPage({
    required this.workspaceId,
    required this.assigneeRepository,
    super.key,
  });

  final String workspaceId;
  final SalesAssigneeRepository assigneeRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SalesAssignee>>(
      stream: assigneeRepository.watchActiveSalesAssignees(
        workspaceId: workspaceId,
      ),
      builder: (context, snapshot) {
        final assignees = snapshot.data ?? const <SalesAssignee>[];
        final names = {
          for (final assignee in assignees)
            assignee.userId: assignee.displayName,
        };

        return BlocBuilder<ActivityOverviewCubit, ActivityOverviewState>(
          builder: (context, state) =>
              _AdminActivityView(state: state, assignees: assignees, names: names),
        );
      },
    );
  }
}

class _AdminActivityView extends StatelessWidget {
  const _AdminActivityView({
    required this.state,
    required this.assignees,
    required this.names,
  });

  final ActivityOverviewState state;
  final List<SalesAssignee> assignees;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ActivityOverviewCubit>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Team activity',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('What your representatives have been doing.'),
          const SizedBox(height: 20),
          DropdownButtonFormField<ActivityPeriod>(
            initialValue: state.period,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Period',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final period in ActivityPeriod.values)
                DropdownMenuItem(value: period, child: Text(period.label)),
            ],
            onChanged: (period) =>
                period == null ? null : cubit.selectPeriod(period),
          ),
          const SizedBox(height: 20),
          _counts(context),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: state.actorUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Representative',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Everyone')),
                    for (final assignee in assignees)
                      DropdownMenuItem(
                        value: assignee.userId,
                        child: Text(
                          assignee.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: cubit.selectActor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<WorkspaceActivityType?>(
                  initialValue: state.type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Activity',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    for (final type in WorkspaceActivityType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(
                          _typeLabel(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: cubit.selectType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _feed(context),
        ],
      ),
    );
  }

  Widget _counts(BuildContext context) {
    if (state.status == ActivityOverviewStatus.failure) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final type in WorkspaceActivityType.values)
          _CountTile(label: _countLabel(type), value: state.countOf(type)),
      ],
    );
  }

  Widget _feed(BuildContext context) {
    if (state.status == ActivityOverviewStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ActivityOverviewStatus.failure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Unable to load team activity.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: context.read<ActivityOverviewCubit>().load,
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (state.activities.isEmpty) {
      return const Text(
        'No activity in this period. Activity appears here as your team '
        'creates leads, converts clients, logs calls, and completes tasks.',
      );
    }

    return Column(
      children: [
        for (final activity in state.activities)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_typeIcon(activity.type)),
            title: Text(_headline(activity)),
            subtitle: Text(
              '${names[activity.actorUserId] ?? 'Former representative'} • '
              '${_timestamp(activity.createdAt)}',
            ),
          ),
      ],
    );
  }

  String _headline(WorkspaceActivity activity) {
    final contact = activity.contactName ?? 'a contact';

    return switch (activity.type) {
      WorkspaceActivityType.leadCreated => 'Added lead $contact',
      WorkspaceActivityType.leadConverted => 'Converted $contact to a client',
      WorkspaceActivityType.callLogged =>
        'Logged a call with $contact${activity.detail == null ? '' : ' (${activity.detail})'}',
      WorkspaceActivityType.taskCompleted =>
        'Completed ${activity.detail ?? 'a task'} for $contact',
    };
  }

  static String _countLabel(WorkspaceActivityType type) => switch (type) {
    WorkspaceActivityType.leadCreated => 'New leads',
    WorkspaceActivityType.leadConverted => 'New clients',
    WorkspaceActivityType.callLogged => 'Calls logged',
    WorkspaceActivityType.taskCompleted => 'Tasks completed',
  };

  static String _typeLabel(WorkspaceActivityType type) => switch (type) {
    WorkspaceActivityType.leadCreated => 'Leads added',
    WorkspaceActivityType.leadConverted => 'Conversions',
    WorkspaceActivityType.callLogged => 'Calls',
    WorkspaceActivityType.taskCompleted => 'Tasks',
  };

  static IconData _typeIcon(WorkspaceActivityType type) => switch (type) {
    WorkspaceActivityType.leadCreated => Icons.person_add_alt_outlined,
    WorkspaceActivityType.leadConverted => Icons.workspace_premium_outlined,
    WorkspaceActivityType.callLogged => Icons.call_outlined,
    WorkspaceActivityType.taskCompleted => Icons.task_alt_outlined,
  };

  static String _timestamp(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} $hour:$minute';
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
