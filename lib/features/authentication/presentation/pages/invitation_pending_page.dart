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
  bool _activated = false;

  @override
  Widget build(BuildContext context) {
    final invitationId = widget.membership.invitationId;
    final canAccept = invitationId != null && invitationId.isNotEmpty;
    final canRetry = _failure?.code == InvitationActionFailureCode.unavailable;
    final canSubmit =
        canAccept &&
        !_accepting &&
        !_activated &&
        (_failure == null || canRetry);

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
                    'You are signed in. Activate this invitation to finish joining Nexus CRM.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the same email address that received the password-setup link.',
                    textAlign: TextAlign.center,
                  ),
                  if (_activated) ...[
                    const SizedBox(height: 16),
                    const _ActivationFeedback(
                      icon: Icons.check_circle_outline,
                      message:
                          'Workspace activated. Opening your sales workspace…',
                    ),
                  ] else if (_failure != null) ...[
                    const SizedBox(height: 16),
                    _ActivationFeedback(
                      icon: Icons.error_outline,
                      message: _failureMessage(_failure!),
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ] else if (!canAccept) ...[
                    const SizedBox(height: 16),
                    _ActivationFeedback(
                      icon: Icons.info_outline,
                      message:
                          'Your invitation details are unavailable. Sign out and sign in again.',
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!_activated)
                    FilledButton(
                      onPressed: canSubmit ? _accept : null,
                      child: _accepting
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Activating workspace…'),
                              ],
                            )
                          : Text(
                              canRetry
                                  ? 'Try again'
                                  : _failure != null || !canAccept
                                  ? 'Activation unavailable'
                                  : 'Activate workspace',
                            ),
                    ),
                  TextButton(
                    onPressed: _accepting || _activated ? null : _signOut,
                    child: const Text('Sign out and use a different account'),
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
      if (mounted) setState(() => _activated = true);
    } on InvitationActionFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } on Object {
      if (mounted) {
        setState(
          () => _failure = const InvitationActionFailure(
            InvitationActionFailureCode.unknown,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  void _signOut() {
    context.read<SessionBloc>().add(const SessionSignOutRequested());
  }

  static String _failureMessage(
    InvitationActionFailure failure,
  ) => switch (failure.code) {
    InvitationActionFailureCode.expired =>
      'This invitation has expired. Ask an administrator to send a new one.',
    InvitationActionFailureCode.accessDenied =>
      'This invitation cannot be activated by this account. Sign out and use the invited account.',
    InvitationActionFailureCode.unavailable =>
      'Workspace activation is temporarily unavailable. Check your connection and try again.',
    _ =>
      'This invitation can no longer be activated. Contact an administrator for help.',
  };
}

class _ActivationFeedback extends StatelessWidget {
  const _ActivationFeedback({
    required this.icon,
    required this.message,
    this.color,
  });

  final IconData icon;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Text(message, style: TextStyle(color: color)),
      ),
    ],
  );
}
