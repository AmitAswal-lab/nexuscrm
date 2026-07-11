import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_form/task_form_cubit.dart';

class TaskFormPage extends StatefulWidget {
  const TaskFormPage({required this.canAssign, super.key});
  final bool canAssign;
  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _notes = TextEditingController(),
      _dueOn = TextEditingController();
  String? _contactId, _assigneeId;
  TaskKind _kind = TaskKind.task;
  bool _didInitialize = false;
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _dueOn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocListener<TaskFormCubit, TaskFormState>(
        listenWhen: (a, b) => a.submissionStatus != b.submissionStatus,
        listener: (context, state) {
          if (state.submissionStatus == TaskFormSubmissionStatus.success) {
            context.pop();
          }
          if (state.submissionStatus == TaskFormSubmissionStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to save this task. Please try again.'),
              ),
            );
          }
        },
        child: SafeArea(
          child: BlocBuilder<TaskFormCubit, TaskFormState>(builder: _build),
        ),
      );
  Widget _build(BuildContext context, TaskFormState state) {
    if (state.taskStatus == TaskFormTaskStatus.loading ||
        !state.contactsReady ||
        !state.assigneesReady) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.taskStatus == TaskFormTaskStatus.notFound) {
      return _Message(message: 'This task is no longer available.');
    }
    if (state.taskStatus == TaskFormTaskStatus.failure ||
        state.contactsFailure != null ||
        state.assigneesFailure != null) {
      return _Message(message: 'Unable to load the task form.');
    }
    final task = state.task;
    _initialize(task, context.read<TaskFormCubit>().fixedAssigneeId);
    final saving =
        state.submissionStatus == TaskFormSubmissionStatus.submitting;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: saving ? null : context.pop,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task == null ? 'New task' : 'Edit task',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _contactId,
                  decoration: const InputDecoration(
                    labelText: 'Linked lead or client',
                    border: OutlineInputBorder(),
                  ),
                  items: state.contacts
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.fullName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: task != null || saving
                      ? null
                      : (v) => setState(() => _contactId = v),
                  validator: (v) =>
                      v == null ? 'Choose a lead or client.' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskKind>(
                  initialValue: _kind,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: TaskKind.task, child: Text('Task')),
                    DropdownMenuItem(
                      value: TaskKind.followUp,
                      child: Text('Follow-up'),
                    ),
                  ],
                  onChanged: saving ? null : (v) => setState(() => _kind = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter a task title.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dueOn,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    helperText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a due date as YYYY-MM-DD.',
                ),
                const SizedBox(height: 16),
                if (widget.canAssign)
                  DropdownButtonFormField<String>(
                    initialValue: _assigneeId,
                    decoration: const InputDecoration(
                      labelText: 'Assigned sales representative',
                      border: OutlineInputBorder(),
                    ),
                    items: state.assignees
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.userId,
                            child: Text(
                              '${a.displayName} (${a.email})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: saving
                        ? null
                        : (v) => setState(() => _assigneeId = v),
                    validator: (v) => v == null ? 'Choose an assignee.' : null,
                  )
                else
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.assignment_ind_outlined),
                    title: Text('Assigned to you'),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
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
                  onPressed: saving ? null : () => _submit(context),
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    saving
                        ? 'Saving…'
                        : task == null
                        ? 'Create task'
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

  void _initialize(CrmTask? task, String fixed) {
    if (!_didInitialize) {
      _didInitialize = true;
      _contactId = task?.contactId;
      _assigneeId = task?.assigneeId ?? fixed;
      _kind = task?.kind ?? TaskKind.task;
      _title.text = task?.title ?? '';
      _notes.text = task?.notes ?? '';
      _dueOn.text = task?.dueOn ?? '';
    }
  }

  void _submit(BuildContext context) {
    if (!(_key.currentState?.validate() ?? false)) return;
    context.read<TaskFormCubit>().submit(
      TaskInput(
        contactId: _contactId!,
        kind: _kind,
        title: _title.text,
        notes: _notes.text.trim().isEmpty ? null : _notes.text,
        assigneeId: _assigneeId!,
        dueOn: _dueOn.text,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        TextButton(onPressed: context.pop, child: const Text('Back to tasks')),
      ],
    ),
  );
}
