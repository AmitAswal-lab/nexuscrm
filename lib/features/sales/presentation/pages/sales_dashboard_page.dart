import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/sales/presentation/cubit/sales_dashboard/sales_dashboard_cubit.dart';

class SalesDashboardPage extends StatelessWidget {
  const SalesDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<SessionBloc, AuthUser?>((bloc) {
      return switch (bloc.state) {
        SessionAuthenticated(:final session) => session.user,
        _ => null,
      };
    });

    return SalesDashboardView(
      userLabel: _userLabel(user),
      dashboardState: context.watch<SalesDashboardCubit>().state,
      onOpenLeads: () => context.go(AppRoutes.salesLeads),
      onOpenTasks: () => context.go(AppRoutes.salesTasks),
      onOpenContact: (contactId) =>
          context.go(AppRoutes.salesContact(contactId)),
      onRetry: context.read<SalesDashboardCubit>().load,
    );
  }

  static String _userLabel(AuthUser? user) {
    final displayName = user?.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return user?.email ?? 'Sales representative';
  }
}

class SalesDashboardView extends StatelessWidget {
  const SalesDashboardView({
    required this.userLabel,
    required this.dashboardState,
    required this.onOpenLeads,
    required this.onOpenTasks,
    required this.onOpenContact,
    required this.onRetry,
    super.key,
  });

  static const _wideSectionBreakpoint = 760.0;
  static const _wideOverviewBreakpoint = 900.0;

  final String userLabel;
  final SalesDashboardState dashboardState;
  final VoidCallback onOpenLeads;
  final VoidCallback onOpenTasks;
  final ValueChanged<String> onOpenContact;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    final isWide =
                        contentConstraints.maxWidth >= _wideSectionBreakpoint;
                    final overviewColumns =
                        switch (contentConstraints.maxWidth) {
                          >= _wideOverviewBreakpoint => 4,
                          >= 600 => 2,
                          _ => 1,
                        };
                    final compactOverview = overviewColumns == 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DashboardHeader(userLabel: userLabel),
                        const SizedBox(height: 24),
                        Text(
                          'Quick actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _QuickActions(
                          onOpenLeads: onOpenLeads,
                          onOpenTasks: onOpenTasks,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: overviewColumns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: compactOverview ? 2.5 : 1.1,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _OverviewCard(
                              icon: Icons.person_search_outlined,
                              label: 'Leads',
                              value: _metricValue(
                                dashboardState,
                                dashboardState.leads.length,
                              ),
                              availability: 'Active assigned leads',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.handshake_outlined,
                              label: 'Clients',
                              value: _metricValue(
                                dashboardState,
                                dashboardState.clientCount,
                              ),
                              availability: 'Converted contacts',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.today_outlined,
                              label: "Today's follow-ups",
                              value: dashboardState.taskReady
                                  ? '${dashboardState.todayFollowUpCount}'
                                  : '…',
                              availability: 'Open follow-ups due today',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.warning_amber_outlined,
                              label: 'Overdue tasks',
                              value: dashboardState.taskReady
                                  ? '${dashboardState.overdueTasks.length}'
                                  : '…',
                              availability: 'Open overdue tasks',
                              compact: compactOverview,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _PipelineSummary(
                          state: dashboardState,
                          onRetry: onRetry,
                        ),
                        const SizedBox(height: 32),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _TodayTasks(state: dashboardState),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _RecentContacts(
                                  state: dashboardState,
                                  onOpenContact: onOpenContact,
                                  onRetry: onRetry,
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _TodayTasks(state: dashboardState),
                              const SizedBox(height: 16),
                              _RecentContacts(
                                state: dashboardState,
                                onOpenContact: onOpenContact,
                                onRetry: onRetry,
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _metricValue(SalesDashboardState state, int value) {
    return switch (state.status) {
      SalesDashboardStatus.loading => '…',
      SalesDashboardStatus.success => '$value',
      SalesDashboardStatus.failure => '—',
    };
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.userLabel});

  final String userLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.trending_up, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales dashboard',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome back, $userLabel',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenLeads, required this.onOpenTasks});

  final VoidCallback onOpenLeads;
  final VoidCallback onOpenTasks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.person_search_outlined,
            label: 'Open leads',
            onTap: onOpenLeads,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.task_alt,
            label: 'Open tasks',
            onTap: onOpenTasks,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.availability,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final String value;
  final String availability;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: compact
            ? Row(
                children: [
                  Icon(icon, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(availability, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(value, style: theme.textTheme.headlineMedium),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: colors.primary),
                  const Spacer(),
                  Text(value, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(availability, style: theme.textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _PipelineSummary extends StatelessWidget {
  const _PipelineSummary({required this.state, required this.onRetry});

  final SalesDashboardState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (state.status) {
          SalesDashboardStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          SalesDashboardStatus.failure => _ContactDataFailure(
            message: 'Unable to load pipeline data.',
            onRetry: onRetry,
          ),
          SalesDashboardStatus.success => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pipeline stages',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${state.pipelineCount} active opportunities',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LeadStage.values
                    .map(
                      (stage) => Chip(
                        label: Text(
                          '${_stageLabel(stage)}: ${state.countStage(stage)}',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        },
      ),
    );
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

class _RecentContacts extends StatelessWidget {
  const _RecentContacts({
    required this.state,
    required this.onOpenContact,
    required this.onRetry,
  });

  final SalesDashboardState state;
  final ValueChanged<String> onOpenContact;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (state.status) {
          SalesDashboardStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          SalesDashboardStatus.failure => _ContactDataFailure(
            message: 'Unable to load recent contacts.',
            onRetry: onRetry,
          ),
          SalesDashboardStatus.success when state.recentContacts.isEmpty =>
            const _EmptyRecentContacts(),
          SalesDashboardStatus.success => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Recent contacts',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...state.recentContacts.map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    contact is Lead
                        ? Icons.person_search_outlined
                        : Icons.person_outline,
                  ),
                  title: Text(contact.fullName),
                  subtitle: Text(contact is Lead ? 'Lead' : 'Client'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onOpenContact(contact.id),
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _EmptyRecentContacts extends StatelessWidget {
  const _EmptyRecentContacts();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.history,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text('Recent contacts', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Created and updated contacts will appear here.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ContactDataFailure extends StatelessWidget {
  const _ContactDataFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _TodayTasks extends StatelessWidget {
  const _TodayTasks({required this.state});
  final SalesDashboardState state;
  @override
  Widget build(BuildContext context) {
    if (!state.taskReady) {
      return const _UnavailableSection(
        icon: Icons.calendar_today_outlined,
        title: 'Today',
        message: 'Loading follow-ups and overdue work…',
      );
    }
    final tasks = [...state.overdueTasks, ...state.todayTasks];
    return _UnavailableSection(
      icon: Icons.calendar_today_outlined,
      title: 'Today',
      message: tasks.isEmpty
          ? 'No follow-ups or overdue work today.'
          : tasks.take(4).map((task) => task.title).join('\n'),
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
