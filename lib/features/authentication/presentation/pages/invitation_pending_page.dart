import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

class InvitationPendingPage extends StatefulWidget {
  const InvitationPendingPage({
    required this.membership,
    required this.invitationRepository,
    super.key,
  });

  final WorkspaceMembership membership;
  final InvitationRepository invitationRepository;

  @override
  State<InvitationPendingPage> createState() => _InvitationPendingPageState();
}

class _InvitationPendingPageState extends State<InvitationPendingPage> {
  InvitationActionFailure? _failure;
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final invitationId = widget.membership.invitationId;
    final canAccept = invitationId != null && invitationId.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Activate your workspace',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'After setting your password through the secure email link, activate your workspace to enter Nexus CRM.',
                    textAlign: TextAlign.center,
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _failureMessage(_failure!),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: canAccept && !_accepting ? _accept : null,
                    child: _accepting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Activate workspace'),
                  ),
                  TextButton(
                    onPressed: _accepting ? null : _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final invitationId = widget.membership.invitationId;
    if (invitationId == null || invitationId.isEmpty) return;
    setState(() {
      _accepting = true;
      _failure = null;
    });
    try {
      await widget.invitationRepository.acceptInvitation(
        workspaceId: widget.membership.workspaceId,
        invitationId: invitationId,
      );
    } on InvitationActionFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _signOut() {
    context.read<SessionBloc>().add(const SessionSignOutRequested());
  }

  static String _failureMessage(InvitationActionFailure failure) =>
      switch (failure.code) {
        InvitationActionFailureCode.expired => 'This invitation has expired.',
        InvitationActionFailureCode.accessDenied =>
          'This invitation does not belong to your account.',
        InvitationActionFailureCode.unavailable =>
          'Workspace activation is temporarily unavailable.',
        _ => 'This invitation can no longer be activated.',
      };
}
