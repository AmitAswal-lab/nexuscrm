import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

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
      onOpenLeads: () => context.go(AppRoutes.salesLeads),
      onOpenTasks: () => context.go(AppRoutes.salesTasks),
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
    required this.onOpenLeads,
    required this.onOpenTasks,
    super.key,
  });

  static const _wideSectionBreakpoint = 760.0;
  static const _wideOverviewBreakpoint = 900.0;

  final String userLabel;
  final VoidCallback onOpenLeads;
  final VoidCallback onOpenTasks;

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
                              availability: 'Available with lead management',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.today_outlined,
                              label: "Today's follow-ups",
                              availability: 'Available with tasks',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.warning_amber_outlined,
                              label: 'Overdue tasks',
                              availability: 'Available with tasks',
                              compact: compactOverview,
                            ),
                            _OverviewCard(
                              icon: Icons.filter_alt_outlined,
                              label: 'Pipeline',
                              availability: 'Available with lead management',
                              compact: compactOverview,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (isWide)
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _UnavailableSection(
                                  icon: Icons.calendar_today_outlined,
                                  title: 'Today',
                                  message:
                                      'Follow-ups and overdue work will appear '
                                      'after task data is connected.',
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _UnavailableSection(
                                  icon: Icons.history,
                                  title: 'Recent leads',
                                  message:
                                      'Recently updated leads will appear after '
                                      'lead management is connected.',
                                ),
                              ),
                            ],
                          )
                        else
                          const Column(
                            children: [
                              _UnavailableSection(
                                icon: Icons.calendar_today_outlined,
                                title: 'Today',
                                message:
                                    'Follow-ups and overdue work will appear '
                                    'after task data is connected.',
                              ),
                              SizedBox(height: 16),
                              _UnavailableSection(
                                icon: Icons.history,
                                title: 'Recent leads',
                                message:
                                    'Recently updated leads will appear after '
                                    'lead management is connected.',
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
    required this.availability,
    required this.compact,
  });

  final IconData icon;
  final String label;
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
                  Text('—', style: theme.textTheme.headlineMedium),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: colors.primary),
                  const Spacer(),
                  Text('—', style: theme.textTheme.headlineMedium),
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
