import 'package:flutter/material.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/membership_management_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

enum TeamCategory { administrators, active, suspended, former }

extension TeamCategoryPresentation on TeamCategory {
  String get title => switch (this) {
    TeamCategory.administrators => 'Administrators',
    TeamCategory.active => 'Active representatives',
    TeamCategory.suspended => 'Suspended representatives',
    TeamCategory.former => 'Former representatives',
  };

  String get description => switch (this) {
    TeamCategory.administrators => 'Manage the workspace and its team.',
    TeamCategory.active => 'Can sign in and work their assigned records.',
    TeamCategory.suspended => 'Access is paused and can be restored.',
    TeamCategory.former => 'Access was revoked permanently.',
  };

  String get emptyMessage => switch (this) {
    TeamCategory.administrators => 'No administrators.',
    TeamCategory.active => 'No active representatives.',
    TeamCategory.suspended => 'No suspended representatives.',
    TeamCategory.former => 'No former representatives.',
  };

  IconData get icon => switch (this) {
    TeamCategory.administrators => Icons.admin_panel_settings_outlined,
    TeamCategory.active => Icons.badge_outlined,
    TeamCategory.suspended => Icons.pause_circle_outline,
    TeamCategory.former => Icons.person_off_outlined,
  };

  bool matches(TeamMember member) => switch (this) {
    TeamCategory.administrators => member.role == WorkspaceRole.admin,
    TeamCategory.active =>
      member.role == WorkspaceRole.salesRep &&
          member.status == MembershipStatus.active,
    TeamCategory.suspended =>
      member.role == WorkspaceRole.salesRep &&
          member.status == MembershipStatus.suspended,
    TeamCategory.former =>
      member.role == WorkspaceRole.salesRep &&
          member.status == MembershipStatus.revoked,
  };
}

class AdminTeamCategoryPage extends StatefulWidget {
  const AdminTeamCategoryPage({
    required this.workspaceId,
    required this.category,
    required this.teamRepository,
    required this.membershipManagementRepository,
    super.key,
  });

  final String workspaceId;
  final TeamCategory category;
  final AdminTeamRepository teamRepository;
  final MembershipManagementRepository membershipManagementRepository;

  @override
  State<AdminTeamCategoryPage> createState() => _AdminTeamCategoryPageState();
}

class _AdminTeamCategoryPageState extends State<AdminTeamCategoryPage> {
  final Map<String, MembershipStatus> _requestedMemberStatus = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.title)),
      body: SafeArea(
        child: StreamBuilder<List<TeamMember>>(
          stream: widget.teamRepository.watchTeam(
            workspaceId: widget.workspaceId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Unable to load team members.'),
              );
            }

            final members = (snapshot.data ?? const <TeamMember>[])
                .where(widget.category.matches)
                .toList(growable: false);

            if (members.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(widget.category.emptyMessage),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _memberTile(members[index]),
            );
          },
        ),
      ),
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
      leading: Icon(widget.category.icon),
      title: Text(member.displayName ?? member.email ?? 'Team member'),
      subtitle: Text(
        busy
            ? pendingStatusLabel(requestedStatus)
            : membershipStatusLabel(member.status),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(membershipFailureMessage(failure))),
        );
      }
    }
  }
}

class AdminPendingInvitationsPage extends StatefulWidget {
  const AdminPendingInvitationsPage({
    required this.workspaceId,
    required this.invitationDirectoryRepository,
    required this.invitationRepository,
    super.key,
  });

  final String workspaceId;
  final InvitationDirectoryRepository invitationDirectoryRepository;
  final InvitationRepository invitationRepository;

  @override
  State<AdminPendingInvitationsPage> createState() =>
      _AdminPendingInvitationsPageState();
}

class _AdminPendingInvitationsPageState
    extends State<AdminPendingInvitationsPage> {
  String? _busyInvitationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending invitations')),
      body: SafeArea(
        child: StreamBuilder<List<WorkspaceInvitation>>(
          stream: widget.invitationDirectoryRepository.watchPendingInvitations(
            workspaceId: widget.workspaceId,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Unable to load pending invitations.'),
              );
            }

            final invitations = snapshot.data ?? const <WorkspaceInvitation>[];
            if (invitations.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No pending invitations.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final invitation in invitations)
                  _invitationCard(context, invitation),
              ],
            );
          },
        ),
      ),
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
            Text('$emailRequestText • Expires ${formatDate(invitation.expiresAt)}'),
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
            result.emailRequestStatus == InvitationEmailRequestResult.accepted
                ? 'Firebase accepted a new setup email request.'
                : 'Firebase did not accept the email request.',
          ),
        ),
      );
    } on InvitationActionFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(invitationFailureMessage(failure))));
      }
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
          '${invitation.email} will no longer be able to use their setup link. '
          'You can invite this address again afterwards.',
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(invitationFailureMessage(failure))));
      }
    } finally {
      if (mounted) setState(() => _busyInvitationId = null);
    }
  }
}

String membershipStatusLabel(MembershipStatus status) => switch (status) {
  MembershipStatus.invited => 'Invited',
  MembershipStatus.active => 'Active',
  MembershipStatus.suspended => 'Suspended',
  MembershipStatus.revoked => 'Revoked',
};

String pendingStatusLabel(MembershipStatus status) => switch (status) {
  MembershipStatus.active => 'Reactivating…',
  MembershipStatus.suspended => 'Suspending…',
  MembershipStatus.revoked => 'Revoking…',
  MembershipStatus.invited => 'Updating…',
};

String formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String membershipFailureMessage(InvitationActionFailure failure) =>
    switch (failure.code) {
      InvitationActionFailureCode.accessDenied =>
        'You no longer have permission to manage this representative.',
      InvitationActionFailureCode.expired =>
        'This representative can no longer be updated.',
      InvitationActionFailureCode.unavailable =>
        'Membership management is temporarily unavailable.',
      _ => 'Unable to update this representative.',
    };

String invitationFailureMessage(InvitationActionFailure failure) =>
    switch (failure.code) {
      InvitationActionFailureCode.rateLimited =>
        'Please wait a moment before requesting another email.',
      InvitationActionFailureCode.accessDenied =>
        'You no longer have permission to manage invitations.',
      InvitationActionFailureCode.expired =>
        'This invitation can no longer be updated.',
      InvitationActionFailureCode.unavailable =>
        'Invitation management is temporarily unavailable.',
      _ => 'Unable to update this invitation.',
    };
