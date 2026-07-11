import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_list/task_list_cubit.dart';

class TaskListPage extends StatelessWidget {
  const TaskListPage({
    required this.title,
    required this.description,
    required this.showAssignee,
    super.key,
  });

  final String title;
  final String description;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                const _TaskFilter(),
                const SizedBox(height: 16),
                Expanded(child: _TaskListBody(showAssignee: showAssignee)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskFilter extends StatelessWidget {
  const _TaskFilter();

  @override
  Widget build(BuildContext context) {
    final selected = context.select<TaskListCubit, TaskListView>(
      (cubit) => cubit.state.view,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<TaskListView>(
        segments: const [
          ButtonSegment(value: TaskListView.today, label: Text('Today')),
          ButtonSegment(value: TaskListView.upcoming, label: Text('Upcoming')),
          ButtonSegment(value: TaskListView.overdue, label: Text('Overdue')),
          ButtonSegment(
            value: TaskListView.completed,
            label: Text('Completed'),
          ),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          context.read<TaskListCubit>().selectView(selection.single);
        },
      ),
    );
  }
}

class _TaskListBody extends StatelessWidget {
  const _TaskListBody({required this.showAssignee});

  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TaskListCubit>().state;

    return switch (state.status) {
      TaskListStatus.loading when state.tasks.isEmpty => const Center(
        child: CircularProgressIndicator(),
      ),
      TaskListStatus.failure when state.tasks.isEmpty => _FailureView(
        failure: state.failure,
      ),
      _ => _TaskResults(state: state, showAssignee: showAssignee),
    };
  }
}

class _TaskResults extends StatelessWidget {
  const _TaskResults({required this.state, required this.showAssignee});

  final TaskListState state;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final tasks = state.visibleTasks;

    if (tasks.isEmpty) {
      return _EmptyView(view: state.view);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _TaskCard(
        task: tasks[index],
        today: state.today,
        showAssignee: showAssignee,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.today,
    required this.showAssignee,
  });

  final CrmTask task;
  final String today;
  final bool showAssignee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowUp = task.kind == TaskKind.followUp;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: task.isCompleted
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.primaryContainer,
              foregroundColor: task.isCompleted
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onPrimaryContainer,
              child: Icon(
                task.isCompleted
                    ? Icons.check
                    : isFollowUp
                    ? Icons.phone_in_talk_outlined
                    : Icons.task_alt_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _dueLabel(task, today),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          task.dueOn.compareTo(today) < 0 && !task.isCompleted
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (task.notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (showAssignee) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Assigned to ${task.assigneeId}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                task.isCompleted
                    ? 'Completed'
                    : isFollowUp
                    ? 'Follow-up'
                    : 'Task',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dueLabel(CrmTask task, String today) {
    if (task.isCompleted) {
      return 'Completed follow-up history';
    }

    if (task.dueOn.compareTo(today) < 0) {
      return 'Overdue · due ${task.dueOn}';
    }

    return task.dueOn == today ? 'Due today' : 'Due ${task.dueOn}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.view});

  final TaskListView view;

  @override
  Widget build(BuildContext context) {
    final message = switch (view) {
      TaskListView.today => 'No tasks due today.',
      TaskListView.upcoming => 'No upcoming tasks.',
      TaskListView.overdue => 'No overdue tasks.',
      TaskListView.completed => 'No completed tasks yet.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Task creation will be added in the next workflow checkpoint.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.failure});

  final TaskFailure? failure;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _message(failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: context.read<TaskListCubit>().load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  static String _message(TaskFailure? failure) {
    return switch (failure?.code) {
      TaskFailureCode.permissionDenied =>
        'You do not have permission to view these tasks.',
      TaskFailureCode.networkUnavailable =>
        'Tasks are unavailable. Check your connection and try again.',
      _ => 'Unable to load tasks right now.',
    };
  }
}
