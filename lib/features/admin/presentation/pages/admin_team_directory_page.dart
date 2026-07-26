import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/membership_management_repository.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_team_category_page.dart';

class AdminTeamDirectoryPage extends StatelessWidget {
  const AdminTeamDirectoryPage({
    required this.workspaceId,
    required this.teamRepository,
    required this.invitationDirectoryRepository,
    required this.invitationRepository,
    required this.membershipManagementRepository,
    required this.onInvite,
    super.key,
  });

  final String workspaceId;
  final AdminTeamRepository teamRepository;
  final InvitationDirectoryRepository invitationDirectoryRepository;
  final InvitationRepository invitationRepository;
  final MembershipManagementRepository membershipManagementRepository;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => SafeArea(
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
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Invite representative'),
          ),
        ),
        const SizedBox(height: 28),
        StreamBuilder<List<TeamMember>>(
          stream: teamRepository.watchTeam(workspaceId: workspaceId),
          builder: _buildCategories,
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<WorkspaceInvitation>>(
          stream: invitationDirectoryRepository.watchPendingInvitations(
            workspaceId: workspaceId,
          ),
          builder: _buildInvitationsEntry,
        ),
      ],
    ),
  );

  Widget _buildCategories(
    BuildContext context,
    AsyncSnapshot<List<TeamMember>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const LinearProgressIndicator();
    }
    if (snapshot.hasError) return const Text('Unable to load team members.');

    final members = snapshot.data ?? const <TeamMember>[];

    return Column(
      children: [
        for (final category in TeamCategory.values)
          _categoryTile(
            context,
            icon: category.icon,
            title: category.title,
            description: category.description,
            count: members.where(category.matches).length,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => AdminTeamCategoryPage(
                  workspaceId: workspaceId,
                  category: category,
                  teamRepository: teamRepository,
                  membershipManagementRepository:
                      membershipManagementRepository,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInvitationsEntry(
    BuildContext context,
    AsyncSnapshot<List<WorkspaceInvitation>> snapshot,
  ) {
    if (snapshot.hasError) {
      return const Text('Unable to load pending invitations.');
    }

    return _categoryTile(
      context,
      icon: Icons.mark_email_unread_outlined,
      title: 'Pending invitations',
      description: 'Invited people who have not activated yet.',
      count: snapshot.data?.length,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => AdminPendingInvitationsPage(
            workspaceId: workspaceId,
            invitationDirectoryRepository: invitationDirectoryRepository,
            invitationRepository: invitationRepository,
          ),
        ),
      ),
    );
  }

  Widget _categoryTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required int? count,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
