import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';

class AdminInviteRepresentativePage extends StatefulWidget {
  const AdminInviteRepresentativePage({
    required this.workspaceId,
    required this.repository,
    super.key,
  });

  final String workspaceId;
  final InvitationRepository repository;

  @override
  State<AdminInviteRepresentativePage> createState() =>
      _AdminInviteRepresentativePageState();
}

class _AdminInviteRepresentativePageState
    extends State<AdminInviteRepresentativePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  InvitationCreationResult? _result;
  InvitationActionFailure? _failure;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            tooltip: 'Back',
            onPressed: _submitting ? null : context.pop,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Invite representative',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'They will set their own password through a secure email link.',
        ),
        const SizedBox(height: 24),
        if (_result == null) _form(context) else _resultState(context),
      ],
    ),
  );

  Widget _form(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailController,
          enabled: !_submitting,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email address',
            hintText: 'name@company.com',
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
              return 'Enter a valid email address.';
            }
            return null;
          },
        ),
        if (_failure != null) ...[
          const SizedBox(height: 12),
          Text(
            _failureMessage(_failure!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send invitation'),
        ),
      ],
    ),
  );

  Widget _resultState(BuildContext context) {
    final result = _result!;
    final sent = result.deliveryStatus == InvitationEmailDeliveryStatus.sent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              sent ? Icons.mark_email_read_outlined : Icons.error_outline,
              size: 40,
              color: sent
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              sent ? 'Invitation sent' : 'Email delivery failed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              sent
                  ? 'A password-setup email was sent to ${result.email}.'
                  : 'The invitation was saved, but the setup email could not be sent.',
            ),
            if (_failure != null) ...[
              const SizedBox(height: 12),
              Text(
                _failureMessage(_failure!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (!sent)
              FilledButton(
                onPressed: _submitting ? null : _retry,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Retry email'),
              ),
            if (!sent) const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _submitting ? null : context.pop,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final result = await widget.repository.createInvitation(
        workspaceId: widget.workspaceId,
        email: _emailController.text,
      );
      if (mounted) setState(() => _result = result);
    } on InvitationActionFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _retry() async {
    final current = _result;
    if (current == null) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final result = await widget.repository.resendInvitation(
        workspaceId: widget.workspaceId,
        invitationId: current.invitationId,
      );
      if (mounted) setState(() => _result = result);
    } on InvitationActionFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static String _failureMessage(InvitationActionFailure failure) =>
      switch (failure.code) {
        InvitationActionFailureCode.duplicate =>
          'This email already has a pending invitation.',
        InvitationActionFailureCode.rateLimited =>
          'Please wait before sending another email.',
        InvitationActionFailureCode.accessDenied =>
          'You no longer have permission to send invitations.',
        InvitationActionFailureCode.unavailable =>
          'Invitation service is temporarily unavailable.',
        _ => 'Unable to send this invitation.',
      };
}
