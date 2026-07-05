import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/lead_form/lead_form_cubit.dart';

class LeadFormPage extends StatefulWidget {
  const LeadFormPage({required this.canAssignOwner, super.key});

  final bool canAssignOwner;

  @override
  State<LeadFormPage> createState() => _LeadFormPageState();
}

class _LeadFormPageState extends State<LeadFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  LeadStage _stage = LeadStage.newLead;
  String _ownerId = '';

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
    return BlocListener<LeadFormCubit, LeadFormState>(
      listenWhen: (previous, current) =>
          previous.submissionStatus != current.submissionStatus,
      listener: (context, state) {
        if (state.submissionStatus == LeadFormSubmissionStatus.success) {
          context.pop();
        } else if (state.submissionStatus == LeadFormSubmissionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_failureMessage(state.submissionFailure))),
          );
        }
      },
      child: SafeArea(
        child: BlocBuilder<LeadFormCubit, LeadFormState>(
          builder: (context, state) {
            if (state.assigneeStatus == AssigneeDirectoryStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.assigneeStatus == AssigneeDirectoryStatus.failure) {
              return _AssigneeFailureView(failure: state.assigneeFailure);
            }

            return _buildForm(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, LeadFormState state) {
    final isSubmitting =
        state.submissionStatus == LeadFormSubmissionStatus.submitting;

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
                        'New lead',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Add the information you have now. You can complete the '
                  'record later.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the lead’s name.'
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

                    if (email.isNotEmpty && !email.contains('@')) {
                      return 'Enter a valid email address.';
                    }

                    return null;
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
                    final email = _emailController.text.trim();

                    return phone.isEmpty && email.isEmpty
                        ? 'Enter an email address or phone number.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LeadStage>(
                  initialValue: _stage,
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
                      : (stage) {
                          if (stage != null) {
                            setState(() => _stage = stage);
                          }
                        },
                ),
                const SizedBox(height: 16),
                if (widget.canAssignOwner)
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
                  )
                else
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.assignment_ind_outlined),
                    title: Text('Assigned to you'),
                    subtitle: Text(
                      'Sales-created leads are automatically assigned to '
                      'their creator.',
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
                FilledButton.icon(
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_outlined),
                  label: Text(isSubmitting ? 'Saving…' : 'Create lead'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    context.read<LeadFormCubit>().submit(
      fullName: _fullNameController.text,
      companyName: _optional(_companyController.text),
      email: _optional(_emailController.text),
      phone: _optional(_phoneController.text),
      notes: _optional(_notesController.text),
      ownerId: _ownerId.isEmpty ? null : _ownerId,
      stage: _stage,
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

  static String _failureMessage(ContactFailure? failure) {
    return switch (failure?.code) {
      ContactFailureCode.permissionDenied =>
        'You do not have permission to create this lead.',
      ContactFailureCode.networkUnavailable =>
        'The lead could not be saved. Check your connection and try again.',
      ContactFailureCode.invalidData =>
        'Review the lead information and try again.',
      _ => 'The lead could not be created right now.',
    };
  }
}

class _AssigneeFailureView extends StatelessWidget {
  const _AssigneeFailureView({required this.failure});

  final ContactFailure? failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load active sales representatives.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: context.read<LeadFormCubit>().loadAssignees,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
