import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_edit/contact_edit_cubit.dart';

class ContactEditPage extends StatefulWidget {
  const ContactEditPage({required this.canAssignOwner, super.key});

  final bool canAssignOwner;

  @override
  State<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String? _initializedContactId;
  String _ownerId = '';
  LeadStage? _leadStage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactEditCubit, ContactEditState>(
      listenWhen: (previous, current) =>
          previous.submissionStatus != current.submissionStatus,
      listener: (context, state) {
        if (state.submissionStatus == ContactEditSubmissionStatus.success) {
          context.pop();
        } else if (state.submissionStatus ==
            ContactEditSubmissionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_failureMessage(state.submissionFailure))),
          );
        }
      },
      child: SafeArea(
        child: BlocBuilder<ContactEditCubit, ContactEditState>(
          builder: (context, state) {
            return switch (state.status) {
              ContactEditStatus.loading => const _LoadMessage(
                message: 'Loading this contact…',
                onRetry: null,
                isLoading: true,
              ),
              ContactEditStatus.notFound => _LoadMessage(
                message: 'This contact is no longer available.',
                onRetry: null,
              ),
              ContactEditStatus.failure => _LoadMessage(
                message: _loadFailureMessage(state.failure),
                onRetry: context.read<ContactEditCubit>().load,
              ),
              ContactEditStatus.ready => _buildForm(context, state),
            };
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ContactEditState state) {
    final contact = state.contact!;
    _initialize(contact);
    final isSubmitting =
        state.submissionStatus == ContactEditSubmissionStatus.submitting;
    final isWaitingForSync =
        state.submissionStatus == ContactEditSubmissionStatus.waitingForSync;
    final isSaving = isSubmitting || isWaitingForSync;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: isSubmitting ? null : context.pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contact is Lead ? 'Edit lead' : 'Edit client',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the contact’s name.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Company (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    return email.isNotEmpty && !email.contains('@')
                        ? 'Enter a valid email address.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    helperText: 'At least an email or phone is required.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    return phone.isEmpty && _emailController.text.trim().isEmpty
                        ? 'Enter an email address or phone number.'
                        : null;
                  },
                ),
                if (contact is Lead) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<LeadStage>(
                    initialValue: _leadStage,
                    decoration: const InputDecoration(
                      labelText: 'Stage',
                      border: OutlineInputBorder(),
                    ),
                    items: LeadStage.values
                        .map(
                          (stage) => DropdownMenuItem(
                            value: stage,
                            child: Text(_stageLabel(stage)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: isSubmitting
                        ? null
                        : (stage) => setState(() => _leadStage = stage),
                  ),
                ],
                const SizedBox(height: 16),
                if (widget.canAssignOwner)
                  switch (state.assigneeStatus) {
                    ContactEditAssigneeStatus.loading =>
                      const _AssigneeLoadingCard(),
                    ContactEditAssigneeStatus.failure => _AssigneeFailureCard(
                      failure: state.assigneeFailure,
                    ),
                    ContactEditAssigneeStatus.ready =>
                      DropdownButtonFormField<String>(
                        initialValue: _ownerId,
                        decoration: const InputDecoration(
                          labelText: 'Assigned sales representative',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Unassigned'),
                          ),
                          if (_ownerId.isNotEmpty &&
                              !state.assignees.any(
                                (assignee) => assignee.userId == _ownerId,
                              ))
                            DropdownMenuItem(
                              value: _ownerId,
                              child: const Text('Current assignee (inactive)'),
                            ),
                          ...state.assignees.map(
                            (assignee) => DropdownMenuItem(
                              value: assignee.userId,
                              child: Text(
                                '${assignee.displayName} (${assignee.email})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: isSubmitting
                            ? null
                            : (ownerId) {
                                setState(() => _ownerId = ownerId ?? '');
                              },
                      ),
                  }
                else
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.assignment_ind_outlined),
                    title: Text('Assigned to you'),
                    subtitle: Text(
                      'Sales representatives cannot reassign contacts.',
                    ),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                if (isWaitingForSync) ...[
                  const _WaitingForSyncCard(),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: isSaving ? null : _submit,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    isSubmitting
                        ? 'Saving…'
                        : isWaitingForSync
                        ? 'Waiting to sync…'
                        : 'Save changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _initialize(CrmContact contact) {
    if (_initializedContactId == contact.id) {
      return;
    }

    _initializedContactId = contact.id;
    _fullNameController.text = contact.fullName;
    _companyController.text = contact.companyName ?? '';
    _emailController.text = contact.email ?? '';
    _phoneController.text = contact.phone ?? '';
    _notesController.text = contact.notes ?? '';
    _ownerId = contact.ownerId ?? '';
    _leadStage = contact is Lead ? contact.stage : null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    context.read<ContactEditCubit>().submit(
      fullName: _fullNameController.text,
      companyName: _optional(_companyController.text),
      email: _optional(_emailController.text),
      phone: _optional(_phoneController.text),
      notes: _optional(_notesController.text),
      ownerId: _ownerId.isEmpty ? null : _ownerId,
      leadStage: _leadStage,
    );
  }

  static String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
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

  static String _loadFailureMessage(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to edit this contact.',
      ContactFailureCode.networkUnavailable =>
        'Unable to load the contact. Check your connection and try again.',
      _ => 'Unable to load this contact right now.',
    };
  }

  static String _failureMessage(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to update this contact.',
      ContactFailureCode.networkUnavailable =>
        'The contact could not be saved. Check your connection and try again.',
      ContactFailureCode.invalidData =>
        'Review the contact information and try again.',
      ContactFailureCode.conflict =>
        'The contact changed. Return to the details and try again.',
      _ => 'The contact could not be updated right now.',
    };
  }
}

class _LoadMessage extends StatelessWidget {
  const _LoadMessage({
    required this.message,
    required this.onRetry,
    this.isLoading = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(),
              )
            else
              const Icon(Icons.edit_off_outlined, size: 52),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (onRetry != null)
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            if (onRetry != null) const SizedBox(height: 8),
            TextButton.icon(
              onPressed: context.pop,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to contacts'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssigneeLoadingCard extends StatelessWidget {
  const _AssigneeLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Loading active sales representatives…')),
          ],
        ),
      ),
    );
  }
}

class _WaitingForSyncCard extends StatelessWidget {
  const _WaitingForSyncCard();

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_upload_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Still saving changes',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Waiting for Firestore to confirm the update. You can go '
                    'back to the contact; do not submit these changes again.',
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: context.pop,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to contact'),
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

class _AssigneeFailureCard extends StatelessWidget {
  const _AssigneeFailureCard({required this.failure});

  final ContactFailure? failure;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.people_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _message,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'You can still update the contact. Its current assignment will '
              'remain unchanged.',
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: context.read<ContactEditCubit>().loadAssignees,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  String get _message {
    return switch (failure?.code) {
      ContactFailureCode.invalidData =>
        'A sales membership is missing required profile information.',
      ContactFailureCode.permissionDenied =>
        'You do not have permission to load sales representatives.',
      ContactFailureCode.networkUnavailable =>
        'Sales representatives are unavailable. Check your connection.',
      _ => 'Unable to load active sales representatives.',
    };
  }
}
