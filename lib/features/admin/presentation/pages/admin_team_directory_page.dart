import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

class AdminTeamDirectoryPage extends StatefulWidget {
  const AdminTeamDirectoryPage({
    required this.workspaceId,
    required this.teamRepository,
    required this.invitationDirectoryRepository,
    required this.invitationRepository,
    required this.onInvite,
    super.key,
  });

  final String workspaceId;
  final AdminTeamRepository teamRepository;
  final InvitationDirectoryRepository invitationDirectoryRepository;
  final InvitationRepository invitationRepository;
  final VoidCallback onInvite;

  @override
  State<AdminTeamDirectoryPage> createState() => _AdminTeamDirectoryPageState();
}

class _AdminTeamDirectoryPageState extends State<AdminTeamDirectoryPage> {
  String? _busyInvitationId;

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
            onPressed: widget.onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Invite representative'),
          ),
        ),
        const SizedBox(height: 28),
        Text('Team members', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StreamBuilder<List<TeamMember>>(
          stream: widget.teamRepository.watchTeam(
            workspaceId: widget.workspaceId,
          ),
          builder: _buildMembers,
        ),
        const SizedBox(height: 28),
        Text(
          'Pending invitations',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<WorkspaceInvitation>>(
          stream: widget.invitationDirectoryRepository.watchPendingInvitations(
            workspaceId: widget.workspaceId,
          ),
          builder: _buildInvitations,
        ),
      ],
    ),
  );

  Widget _buildMembers(
    BuildContext context,
    AsyncSnapshot<List<TeamMember>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const LinearProgressIndicator();
    }
    if (snapshot.hasError) return const Text('Unable to load team members.');

    final members = (snapshot.data ?? const <TeamMember>[])
        .where((member) => member.status != MembershipStatus.invited)
        .toList(growable: false);
    if (members.isEmpty) return const Text('No existing team members.');

    return Column(
      children: [
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              member.role == WorkspaceRole.admin
                  ? Icons.admin_panel_settings_outlined
                  : Icons.badge_outlined,
            ),
            title: Text(member.displayName ?? member.email ?? 'Team member'),
            subtitle: Text(
              '${member.role == WorkspaceRole.admin ? 'Administrator' : 'Sales representative'} • ${_membershipStatus(member.status)}',
            ),
          ),
      ],
    );
  }

  Widget _buildInvitations(
    BuildContext context,
    AsyncSnapshot<List<WorkspaceInvitation>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const LinearProgressIndicator();
    }
    if (snapshot.hasError) {
      return const Text('Unable to load pending invitations.');
    }

    final invitations = snapshot.data ?? const <WorkspaceInvitation>[];
    if (invitations.isEmpty) return const Text('No pending invitations.');

    return Column(
      children: [
        for (final invitation in invitations)
          _invitationCard(context, invitation),
      ],
    );
  }

  Widget _invitationCard(BuildContext context, WorkspaceInvitation invitation) {
    final busy = _busyInvitationId == invitation.id;
    final deliveryText = switch (invitation.deliveryStatus) {
      InvitationDeliveryStatus.pending ||
      InvitationDeliveryStatus.sending => 'Preparing email',
      InvitationDeliveryStatus.sent => 'Email sent',
      InvitationDeliveryStatus.failed => 'Email delivery failed',
    };
    final resendLabel =
        invitation.deliveryStatus == InvitationDeliveryStatus.failed
        ? 'Retry email'
        : 'Resend';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invitation.email,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('$deliveryText • Expires ${_date(invitation.expiresAt)}'),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: busy ? null : () => _resend(invitation),
                  child: Text(resendLabel),
                ),
                TextButton(
                  onPressed: busy ? null : () => _confirmRevoke(invitation),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Revoke'),
                ),
                if (busy) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resend(WorkspaceInvitation invitation) async {
    setState(() => _busyInvitationId = invitation.id);
    try {
      final result = await widget.invitationRepository.resendInvitation(
        workspaceId: widget.workspaceId,
        invitationId: invitation.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deliveryStatus.name == 'sent'
                ? 'Invitation email sent.'
                : 'Invitation is saved, but email delivery failed.',
          ),
        ),
      );
    } on InvitationActionFailure catch (failure) {
      if (mounted) _showFailure(failure);
    } finally {
      if (mounted) setState(() => _busyInvitationId = null);
    }
  }

  Future<void> _confirmRevoke(WorkspaceInvitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke invitation?'),
        content: Text(
          '${invitation.email} will no longer be able to complete onboarding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Revoke invitation'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyInvitationId = invitation.id);
    try {
      await widget.invitationRepository.revokeInvitation(
        workspaceId: widget.workspaceId,
        invitationId: invitation.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invitation revoked.')));
    } on InvitationActionFailure catch (failure) {
      if (mounted) _showFailure(failure);
    } finally {
      if (mounted) setState(() => _busyInvitationId = null);
    }
  }

  void _showFailure(InvitationActionFailure failure) {
    final message = switch (failure.code) {
      InvitationActionFailureCode.rateLimited =>
        'Please wait before sending another email.',
      InvitationActionFailureCode.expired => 'This invitation has expired.',
      InvitationActionFailureCode.accessDenied =>
        'You no longer have permission to manage invitations.',
      InvitationActionFailureCode.unavailable =>
        'Invitation service is temporarily unavailable.',
      _ => 'Unable to update this invitation.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _membershipStatus(MembershipStatus status) => switch (status) {
    MembershipStatus.invited => 'Invited',
    MembershipStatus.active => 'Active',
    MembershipStatus.suspended => 'Suspended',
    MembershipStatus.revoked => 'Revoked',
  };

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
