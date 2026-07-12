import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
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
  CallOutcome? _outcome;

  @override
  void dispose() {
    _noteController.dispose();
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
      ),
    );
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
