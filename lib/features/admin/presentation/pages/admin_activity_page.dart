import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/presentation/cubit/activity_overview/activity_overview_cubit.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

class AdminActivityPage extends StatelessWidget {
  const AdminActivityPage({
    required this.workspaceId,
    required this.teamRepository,
    required this.activityRepository,
    super.key,
  });

  final String workspaceId;
  final AdminTeamRepository teamRepository;
  final ActivityRepository activityRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityOverviewCubit, ActivityOverviewState>(
      builder: (context, state) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Team activity',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('A glance at what your team has been doing.'),
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
              onChanged: (period) => period == null
                  ? null
                  : context.read<ActivityOverviewCubit>().selectPeriod(period),
            ),
            const SizedBox(height: 20),
            if (state.status == ActivityOverviewStatus.failure)
              _failure(context)
            else ...[
              _countGrid(context, state),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openFeed(context),
                  icon: const Icon(Icons.history),
                  label: const Text('View all activity'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _failure(BuildContext context) => Column(
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

  Widget _countGrid(BuildContext context, ActivityOverviewState state) {
    const types = WorkspaceActivityType.values;
    final loading = state.status == ActivityOverviewStatus.loading;

    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _CountTile(
                      label: countLabel(types[row * 2 + column]),
                      icon: activityIcon(types[row * 2 + column]),
                      value: loading
                          ? null
                          : state.countOf(types[row * 2 + column]),
                      onTap: () =>
                          _openFeed(context, type: types[row * 2 + column]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _openFeed(BuildContext context, {WorkspaceActivityType? type}) {
    final period = context.read<ActivityOverviewCubit>().state.period;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AdminActivityFeedPage(
          workspaceId: workspaceId,
          teamRepository: teamRepository,
          activityRepository: activityRepository,
          initialType: type,
          initialPeriod: period,
        ),
      ),
    );
  }
}

class AdminActivityFeedPage extends StatelessWidget {
  const AdminActivityFeedPage({
    required this.workspaceId,
    required this.teamRepository,
    required this.activityRepository,
    this.initialType,
    this.initialPeriod = ActivityPeriod.week,
    super.key,
  });

  final String workspaceId;
  final AdminTeamRepository teamRepository;
  final ActivityRepository activityRepository;
  final WorkspaceActivityType? initialType;
  final ActivityPeriod initialPeriod;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActivityOverviewCubit(
        activityRepository: activityRepository,
        workspaceId: workspaceId,
        initialType: initialType,
      )..selectPeriod(initialPeriod),
      child: Scaffold(
        appBar: AppBar(title: const Text('Team activity')),
        body: StreamBuilder<List<TeamMember>>(
          stream: teamRepository.watchTeam(workspaceId: workspaceId),
          builder: (context, snapshot) {
            final members = _selectableMembers(snapshot.data);

            return BlocBuilder<ActivityOverviewCubit, ActivityOverviewState>(
              builder: (context, state) => _body(context, state, members),
            );
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    ActivityOverviewState state,
    List<TeamMember> members,
  ) {
    final cubit = context.read<ActivityOverviewCubit>();
    final names = {
      for (final member in members) member.userId: memberLabel(member),
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: state.actorUserId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Team member',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Everyone'),
                    ),
                    for (final member in members)
                      DropdownMenuItem(
                        value: member.userId,
                        child: Text(
                          memberLabel(member),
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
                          filterLabel(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: cubit.selectType,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          switch (state.status) {
            ActivityOverviewStatus.loading => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            ActivityOverviewStatus.failure => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to load team activity.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: cubit.load,
                  child: const Text('Try again'),
                ),
              ],
            ),
            ActivityOverviewStatus.success when state.activities.isEmpty =>
              const Text(
                'No activity in this period. Activity appears here as your '
                'team creates leads, converts clients, logs calls, and '
                'completes tasks.',
              ),
            ActivityOverviewStatus.success => Column(
              children: [
                for (final activity in state.activities)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(activityIcon(activity.type)),
                    title: Text(activityHeadline(activity)),
                    subtitle: Text(
                      '${names[activity.actorUserId] ?? 'Former representative'}'
                      ' • ${activityTimestamp(activity.createdAt)}',
                    ),
                  ),
              ],
            ),
          },
        ],
      ),
    );
  }

  static List<TeamMember> _selectableMembers(List<TeamMember>? members) {
    return (members ?? const <TeamMember>[])
        .where((member) => member.status == MembershipStatus.active)
        .toList(growable: false);
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final int? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const Spacer(),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value == null ? '—' : '$value',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

String memberLabel(TeamMember member) =>
    member.displayName ??
    member.email ??
    (member.role == WorkspaceRole.admin ? 'Administrator' : 'Representative');

String countLabel(WorkspaceActivityType type) => switch (type) {
  WorkspaceActivityType.leadCreated => 'New leads',
  WorkspaceActivityType.leadConverted => 'New clients',
  WorkspaceActivityType.callLogged => 'Calls logged',
  WorkspaceActivityType.taskCompleted => 'Tasks completed',
};

String filterLabel(WorkspaceActivityType type) => switch (type) {
  WorkspaceActivityType.leadCreated => 'Leads added',
  WorkspaceActivityType.leadConverted => 'Conversions',
  WorkspaceActivityType.callLogged => 'Calls',
  WorkspaceActivityType.taskCompleted => 'Tasks',
};

IconData activityIcon(WorkspaceActivityType type) => switch (type) {
  WorkspaceActivityType.leadCreated => Icons.person_add_alt_outlined,
  WorkspaceActivityType.leadConverted => Icons.workspace_premium_outlined,
  WorkspaceActivityType.callLogged => Icons.call_outlined,
  WorkspaceActivityType.taskCompleted => Icons.task_alt_outlined,
};

String activityHeadline(WorkspaceActivity activity) {
  final contact = activity.contactName ?? 'a contact';

  return switch (activity.type) {
    WorkspaceActivityType.leadCreated => 'Added lead $contact',
    WorkspaceActivityType.leadConverted => 'Converted $contact to a client',
    WorkspaceActivityType.callLogged =>
      'Logged a call with $contact'
          '${activity.detail == null ? '' : ' (${activity.detail})'}',
    WorkspaceActivityType.taskCompleted =>
      'Completed ${activity.detail ?? 'a task'} for $contact',
  };
}

String activityTimestamp(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$day/$month/${local.year} $hour:$minute';
}
