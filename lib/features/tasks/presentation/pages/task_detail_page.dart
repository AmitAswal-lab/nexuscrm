import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_detail/task_detail_cubit.dart';

class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({required this.onEdit, super.key});
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: BlocConsumer<TaskDetailCubit, TaskDetailState>(
      listenWhen: (a, b) => a.actionStatus != b.actionStatus,
      listener: (context, state) {
        if (state.actionStatus == TaskActionStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update this task. Please try again.'),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == TaskDetailStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status != TaskDetailStatus.ready) {
          return Center(
            child: TextButton(
              onPressed: context.pop,
              child: const Text('Back to tasks'),
            ),
          );
        }
        final task = state.task!;
        final busy = state.actionStatus == TaskActionStatus.submitting;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: context.pop,
                        icon: const Icon(Icons.arrow_back),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit task',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.kind.name == 'followUp' ? 'Follow-up' : 'Task',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(task.isCompleted ? 'Completed' : 'Open'),
                          const SizedBox(height: 8),
                          Text('Due ${task.dueOn}'),
                          const SizedBox(height: 8),
                          Text('Linked contact: ${task.contactId}'),
                          const SizedBox(height: 8),
                          Text('Assigned to ${task.assigneeId}'),
                          if (task.notes != null) ...[
                            const SizedBox(height: 16),
                            Text(task.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : (task.isCompleted
                              ? context.read<TaskDetailCubit>().reopen
                              : context.read<TaskDetailCubit>().complete),
                    icon: Icon(
                      task.isCompleted ? Icons.replay_outlined : Icons.check,
                    ),
                    label: Text(
                      busy
                          ? 'Updating…'
                          : task.isCompleted
                          ? 'Reopen task'
                          : 'Complete task',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
