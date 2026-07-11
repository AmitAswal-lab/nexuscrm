part of 'task_list_cubit.dart';

enum TaskListStatus { loading, success, failure }

enum TaskListView { today, upcoming, overdue, completed }

final class TaskListState extends Equatable {
  const TaskListState({
    required this.today,
    this.status = TaskListStatus.loading,
    this.tasks = const <CrmTask>[],
    this.view = TaskListView.today,
    this.failure,
  });

  final TaskListStatus status;
  final List<CrmTask> tasks;
  final TaskListView view;
  final String today;
  final TaskFailure? failure;

  List<CrmTask> get visibleTasks {
    return switch (view) {
      TaskListView.today =>
        tasks
            .where((task) => !task.isCompleted && task.dueOn == today)
            .toList(growable: false),
      TaskListView.upcoming =>
        tasks
            .where(
              (task) => !task.isCompleted && task.dueOn.compareTo(today) > 0,
            )
            .toList(growable: false),
      TaskListView.overdue =>
        tasks
            .where(
              (task) => !task.isCompleted && task.dueOn.compareTo(today) < 0,
            )
            .toList(growable: false),
      TaskListView.completed =>
        tasks.where((task) => task.isCompleted).toList(growable: false),
    };
  }

  TaskListState copyWith({TaskListView? view}) {
    return TaskListState(
      status: status,
      tasks: tasks,
      view: view ?? this.view,
      today: today,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, tasks, view, today, failure];
}
