import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/failures/task_failure.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_list/task_list_cubit.dart';

class TaskListPage extends StatelessWidget {
  const TaskListPage({
    required this.title,
    required this.description,
    required this.showAssignee,
    required this.onCreateTask,
    required this.onOpenTask,
    required this.workspaceId,
    this.teamRepository,
    super.key,
  });

  final String title;
  final String description;
  final bool showAssignee;
  final VoidCallback onCreateTask;
  final ValueChanged<String> onOpenTask;
  final String workspaceId;
  final AdminTeamRepository? teamRepository;

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onCreateTask,
                      icon: const Icon(Icons.add),
                      label: const Text('New task'),
                    ),
                  ],
                ),
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
                Expanded(
                  child: StreamBuilder<List<TeamMember>>(
                    stream: showAssignee
                        ? teamRepository?.watchTeam(workspaceId: workspaceId)
                        : null,
                    builder: (context, snapshot) {
                      final members = snapshot.data ?? const <TeamMember>[];
                      final Map<String, String> names = {
                        for (final member in members) member.userId:
                          member.label,
                      };
                      return _TaskListBody(
                        showAssignee: showAssignee,
                        onOpenTask: onOpenTask,
                        assigneeNames: names,
                      );
                    },
                  ),
                ),
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
          ButtonSegment(
            value: TaskListView.cancelled,
            label: Text('Cancelled'),
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
  const _TaskListBody({
    required this.showAssignee,
    required this.onOpenTask,
    required this.assigneeNames,
  });

  final bool showAssignee;
  final ValueChanged<String> onOpenTask;
  final Map<String, String> assigneeNames;

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
      _ => _TaskResults(
        state: state,
        showAssignee: showAssignee,
        onOpenTask: onOpenTask,
        assigneeNames: assigneeNames,
      ),
    };
  }
}

class _TaskResults extends StatelessWidget {
  const _TaskResults({
    required this.state,
    required this.showAssignee,
    required this.onOpenTask,
    required this.assigneeNames,
  });

  final TaskListState state;
  final bool showAssignee;
  final ValueChanged<String> onOpenTask;
  final Map<String, String> assigneeNames;

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
        onTap: () => onOpenTask(tasks[index].id),
        assigneeName: assigneeNames[tasks[index].assigneeId],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.today,
    required this.showAssignee,
    required this.onTap,
    required this.assigneeName,
  });

  final CrmTask task;
  final String today;
  final bool showAssignee;
  final VoidCallback onTap;
  final String? assigneeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowUp = task.kind == TaskKind.followUp;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: switch (task.status) {
                  TaskStatus.open => theme.colorScheme.primaryContainer,
                  TaskStatus.completed => theme.colorScheme.secondaryContainer,
                  TaskStatus.cancelled =>
                    theme.colorScheme.surfaceContainerHighest,
                },
                foregroundColor: switch (task.status) {
                  TaskStatus.open => theme.colorScheme.onPrimaryContainer,
                  TaskStatus.completed =>
                    theme.colorScheme.onSecondaryContainer,
                  TaskStatus.cancelled => theme.colorScheme.onSurfaceVariant,
                },
                child: Icon(switch (task.status) {
                  TaskStatus.completed => Icons.check,
                  TaskStatus.cancelled => Icons.cancel_outlined,
                  TaskStatus.open when isFollowUp =>
                    Icons.phone_in_talk_outlined,
                  TaskStatus.open => Icons.task_alt_outlined,
                }),
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
                        color: task.dueOn.compareTo(today) < 0 && task.isOpen
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
                        'Assigned to ${assigneeName ?? 'a former member'}',
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
                label: Text(switch (task.status) {
                  TaskStatus.completed => 'Completed',
                  TaskStatus.cancelled => 'Cancelled',
                  TaskStatus.open when isFollowUp => 'Follow-up',
                  TaskStatus.open => 'Task',
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dueLabel(CrmTask task, String today) {
    if (task.isCompleted) {
      return 'Completed follow-up history';
    }

    if (task.isCancelled) {
      return 'Cancelled · was due ${task.dueOn}';
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
      TaskListView.cancelled => 'No cancelled tasks.',
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
            Text(_hint(view), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  static String _hint(TaskListView view) {
    return switch (view) {
      TaskListView.today ||
      TaskListView.upcoming ||
      TaskListView.overdue => 'Use New task to schedule follow-up work.',
      TaskListView.completed => 'Tasks you finish will appear here.',
      TaskListView.cancelled =>
        'Tasks you cancel will appear here, and can be reopened.',
    };
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
