import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_follow_up_input.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/presentation/cubit/call_note_form/call_note_form_cubit.dart';

class CallNoteFormPage extends StatefulWidget {
  const CallNoteFormPage({super.key});

  @override
  State<CallNoteFormPage> createState() => _CallNoteFormPageState();
}

class _CallNoteFormPageState extends State<CallNoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _followUpTitleController = TextEditingController();
  final _followUpDueOnController = TextEditingController();
  CallOutcome? _outcome;
  String? _assigneeId;
  bool _createFollowUp = false;

  @override
  void dispose() {
    _noteController.dispose();
    _followUpTitleController.dispose();
    _followUpDueOnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallNoteFormCubit, CallNoteFormState>(
      listenWhen: (previous, current) =>
          previous.submissionStatus != current.submissionStatus,
      listener: (context, state) {
        switch (state.submissionStatus) {
          case CallNoteSubmissionStatus.success:
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Call note saved.')));
            context.pop();
          case CallNoteSubmissionStatus.failure:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to save this call note. Please try again.',
                ),
              ),
            );
          case CallNoteSubmissionStatus.idle ||
              CallNoteSubmissionStatus.submitting:
            break;
        }
      },
      child: SafeArea(
        child: BlocBuilder<CallNoteFormCubit, CallNoteFormState>(
          builder: _build,
        ),
      ),
    );
  }

  Widget _build(BuildContext context, CallNoteFormState state) {
    final isSaving =
        state.submissionStatus == CallNoteSubmissionStatus.submitting;
    final cubit = context.read<CallNoteFormCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: isSaving ? null : context.pop,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Log call note',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Record the result of your call. This note cannot be edited after saving.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<CallOutcome>(
                  initialValue: _outcome,
                  decoration: const InputDecoration(
                    labelText: 'Call outcome',
                    border: OutlineInputBorder(),
                  ),
                  items: CallOutcome.values
                      .map(
                        (outcome) => DropdownMenuItem(
                          value: outcome,
                          child: Text(_outcomeLabel(outcome)),
                        ),
                      )
                      .toList(),
                  onChanged: isSaving
                      ? null
                      : (outcome) => setState(() => _outcome = outcome),
                  validator: (value) =>
                      value == null ? 'Choose a call outcome.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  enabled: !isSaving,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Call notes (optional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Create a follow-up task'),
                  subtitle: const Text(
                    'Schedule the next action while saving this call note.',
                  ),
                  value: _createFollowUp,
                  onChanged: isSaving
                      ? null
                      : (value) => setState(() => _createFollowUp = value),
                ),
                if (_createFollowUp) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _followUpTitleController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Follow-up title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _createFollowUp &&
                            (value == null || value.trim().isEmpty)
                        ? 'Enter a follow-up title.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _followUpDueOnController,
                    readOnly: true,
                    onTap: isSaving ? null : _selectFollowUpDate,
                    decoration: const InputDecoration(
                      labelText: 'Follow-up due date',
                      helperText: 'Choose a calendar date.',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        _createFollowUp &&
                            !RegExp(
                              r'^\d{4}-\d{2}-\d{2}$',
                            ).hasMatch(value?.trim() ?? '')
                        ? 'Choose a follow-up due date.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (cubit.canAssignFollowUp)
                    _adminAssigneeField(state, isSaving)
                  else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.assignment_ind_outlined),
                      title: Text('Follow-up assigned to you'),
                    ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: isSaving ? null : () => _submit(context),
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? 'Saving…' : 'Save call note'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    context.read<CallNoteFormCubit>().submit(
      CallNoteInput(
        outcome: _outcome!,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text,
        followUp: _createFollowUp
            ? CallNoteFollowUpInput(
                title: _followUpTitleController.text,
                dueOn: _followUpDueOnController.text,
                assigneeId: context.read<CallNoteFormCubit>().canAssignFollowUp
                    ? _assigneeId ?? ''
                    : context.read<CallNoteFormCubit>().fixedAssigneeId,
              )
            : null,
      ),
    );
  }

  Widget _adminAssigneeField(CallNoteFormState state, bool isSaving) {
    if (state.assigneesFailed) {
      return const Text('Unable to load sales representatives.');
    }
    if (!state.assigneesReady) {
      return const LinearProgressIndicator();
    }
    return DropdownButtonFormField<String>(
      initialValue: _assigneeId,
      decoration: const InputDecoration(
        labelText: 'Assigned sales representative',
        border: OutlineInputBorder(),
      ),
      items: state.assignees
          .map(
            (assignee) => DropdownMenuItem(
              value: assignee.userId,
              child: Text('${assignee.displayName} (${assignee.email})'),
            ),
          )
          .toList(),
      onChanged: isSaving
          ? null
          : (value) => setState(() => _assigneeId = value),
      validator: (value) =>
          _createFollowUp && value == null ? 'Choose an assignee.' : null,
    );
  }

  Future<void> _selectFollowUpDate() async {
    final existing = DateTime.tryParse(_followUpDueOnController.text);
    final selected = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected != null && mounted) {
      setState(() {
        _followUpDueOnController.text =
            '${selected.year}-${selected.month.toString().padLeft(2, '0')}-${selected.day.toString().padLeft(2, '0')}';
      });
    }
  }

  String _outcomeLabel(CallOutcome outcome) {
    return switch (outcome) {
      CallOutcome.connected => 'Connected',
      CallOutcome.voicemail => 'Left voicemail',
      CallOutcome.noAnswer => 'No answer',
      CallOutcome.wrongNumber => 'Wrong number',
      CallOutcome.other => 'Other',
    };
  }
}
