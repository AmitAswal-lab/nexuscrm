import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/membership_management_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

class AdminTeamDirectoryPage extends StatefulWidget {
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
  State<AdminTeamDirectoryPage> createState() => _AdminTeamDirectoryPageState();
}

class _AdminTeamDirectoryPageState extends State<AdminTeamDirectoryPage> {
  String? _busyInvitationId;
  final Map<String, MembershipStatus> _requestedMemberStatus = {};

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
      children: [for (final member in members) _memberTile(member)],
    );
  }

  Widget _memberTile(TeamMember member) {
    final requestedStatus = _requestedMemberStatus[member.userId];
    final busy = requestedStatus != null && requestedStatus != member.status;
    final canManage =
        member.role == WorkspaceRole.salesRep &&
        (member.status == MembershipStatus.active ||
            member.status == MembershipStatus.suspended);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        member.role == WorkspaceRole.admin
            ? Icons.admin_panel_settings_outlined
            : Icons.badge_outlined,
      ),
      title: Text(member.displayName ?? member.email ?? 'Team member'),
      subtitle: Text(
        '${member.role == WorkspaceRole.admin ? 'Administrator' : 'Sales representative'} • '
        '${busy ? _pendingStatus(requestedStatus) : _membershipStatus(member.status)}',
      ),
      trailing: busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : canManage
          ? PopupMenuButton<MembershipStatus>(
              tooltip: 'Manage representative',
              onSelected: (status) => _confirmMembershipChange(member, status),
              itemBuilder: (context) => [
                if (member.status == MembershipStatus.active)
                  const PopupMenuItem(
                    value: MembershipStatus.suspended,
                    child: Text('Suspend access'),
                  ),
                if (member.status == MembershipStatus.suspended)
                  const PopupMenuItem(
                    value: MembershipStatus.active,
                    child: Text('Reactivate access'),
                  ),
                const PopupMenuItem(
                  value: MembershipStatus.revoked,
                  child: Text('Revoke access'),
                ),
              ],
            )
          : null,
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
    final emailRequestText = switch (invitation.emailRequestStatus) {
      InvitationEmailRequestStatus.pending ||
      InvitationEmailRequestStatus.requesting => 'Requesting setup email',
      InvitationEmailRequestStatus.accepted => 'Email request accepted',
      InvitationEmailRequestStatus.failed => 'Email request failed',
    };
    final resendLabel =
        invitation.emailRequestStatus == InvitationEmailRequestStatus.failed
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
            Text('$emailRequestText • Expires ${_date(invitation.expiresAt)}'),
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
            result.emailRequestStatus.name == 'accepted'
                ? 'Firebase accepted the password-setup email request.'
                : 'Invitation is saved, but Firebase did not accept the email request.',
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

  Future<void> _confirmMembershipChange(
    TeamMember member,
    MembershipStatus status,
  ) async {
    final verb = switch (status) {
      MembershipStatus.suspended => 'Suspend',
      MembershipStatus.active => 'Reactivate',
      MembershipStatus.revoked => 'Revoke',
      MembershipStatus.invited => throw ArgumentError.value(status),
    };
    final completedMessage = switch (status) {
      MembershipStatus.suspended => 'Access suspended.',
      MembershipStatus.active => 'Access reactivated.',
      MembershipStatus.revoked => 'Access revoked.',
      MembershipStatus.invited => throw ArgumentError.value(status),
    };
    final label = member.displayName ?? member.email ?? 'this representative';
    final explanation = switch (status) {
      MembershipStatus.suspended =>
        '$label keeps their account and their assigned leads, clients, and '
            'tasks, but cannot sign in until you reactivate them.',
      MembershipStatus.active =>
        '$label can sign in again and returns to the leads, clients, and '
            'tasks they already had.',
      MembershipStatus.revoked =>
        'This is permanent and cannot be undone. $label loses workspace '
            'access and their sign-in account is deleted. Bringing them back '
            'later means inviting them again as a new representative.',
      MembershipStatus.invited => throw ArgumentError.value(status),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$verb access for $label?'),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: status == MembershipStatus.revoked
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('$verb access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_requestedMemberStatus.containsKey(member.userId) &&
        _requestedMemberStatus[member.userId] != member.status) {
      return;
    }

    setState(() => _requestedMemberStatus[member.userId] = status);
    try {
      await widget.membershipManagementRepository
          .updateSalesRepresentativeStatus(
            workspaceId: widget.workspaceId,
            userId: member.userId,
            status: status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(completedMessage)));
    } on InvitationActionFailure catch (failure) {
      if (mounted) {
        setState(() => _requestedMemberStatus.remove(member.userId));
        _showMembershipFailure(failure);
      }
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

  void _showMembershipFailure(InvitationActionFailure failure) {
    final message = switch (failure.code) {
      InvitationActionFailureCode.accessDenied =>
        'You no longer have permission to manage representatives.',
      InvitationActionFailureCode.unavailable =>
        'Member management is temporarily unavailable.',
      _ => 'This access change is no longer available.',
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

  static String _pendingStatus(MembershipStatus status) => switch (status) {
    MembershipStatus.active => 'Reactivating…',
    MembershipStatus.suspended => 'Suspending…',
    MembershipStatus.revoked => 'Revoking…',
    MembershipStatus.invited => 'Updating…',
  };

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
