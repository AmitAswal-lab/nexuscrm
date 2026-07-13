import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

class AdminTeamDirectoryPage extends StatelessWidget {
  const AdminTeamDirectoryPage({
    required this.workspaceId,
    required this.repository,
    super.key,
  });
  final String workspaceId;
  final AdminTeamRepository repository;
  @override
  Widget build(BuildContext context) => StreamBuilder<List<TeamMember>>(
    stream: repository.watchTeam(workspaceId: workspaceId),
    builder: (context, snapshot) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: context.pop,
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          const SizedBox(height: 12),
          Text('Team', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Workspace representatives and access states.'),
          const SizedBox(height: 20),
          if (snapshot.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (snapshot.hasError)
            const Text('Unable to load the team directory.'),
          if (!snapshot.hasError && snapshot.hasData && snapshot.data!.isEmpty)
            const Text('No team members found.'),
          for (final member in snapshot.data ?? const <TeamMember>[])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                member.role == WorkspaceRole.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.badge_outlined,
              ),
              title: Text(member.displayName ?? member.email ?? 'Team member'),
              subtitle: Text(
                '${member.role == WorkspaceRole.admin ? 'Administrator' : 'Sales representative'} • ${_status(member.status)}',
              ),
            ),
        ],
      ),
    ),
  );
  static String _status(MembershipStatus status) => switch (status) {
    MembershipStatus.invited => 'Invited',
    MembershipStatus.active => 'Active',
    MembershipStatus.suspended => 'Suspended',
    MembershipStatus.revoked => 'Revoked',
  };
}
