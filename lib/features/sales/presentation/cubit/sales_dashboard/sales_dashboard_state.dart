part of 'sales_dashboard_cubit.dart';

enum SalesDashboardStatus { loading, success, failure }

final class SalesDashboardState extends Equatable {
  const SalesDashboardState({
    this.status = SalesDashboardStatus.loading,
    this.contacts = const <CrmContact>[],
    this.failure,
    this.tasks = const <CrmTask>[],
    this.taskReady = false,
  });

  final SalesDashboardStatus status;
  final List<CrmContact> contacts;
  final ContactFailure? failure;
  final List<CrmTask> tasks;
  final bool taskReady;

  String get today => DateTime.now().toIso8601String().substring(0, 10);
  List<CrmTask> get todayTasks => tasks
      .where((task) => !task.isCompleted && task.dueOn == today)
      .toList(growable: false);
  List<CrmTask> get overdueTasks => tasks
      .where((task) => !task.isCompleted && task.dueOn.compareTo(today) < 0)
      .toList(growable: false);
  int get todayFollowUpCount =>
      todayTasks.where((task) => task.kind == TaskKind.followUp).length;
  SalesDashboardState copyWith({List<CrmTask>? tasks, bool? taskReady}) =>
      SalesDashboardState(
        status: status,
        contacts: contacts,
        failure: failure,
        tasks: tasks ?? this.tasks,
        taskReady: taskReady ?? this.taskReady,
      );

  List<Lead> get leads => contacts.whereType<Lead>().toList(growable: false);

  int get clientCount => contacts.whereType<ClientContact>().length;

  int get pipelineCount =>
      leads.where((lead) => lead.stage != LeadStage.lost).length;

  int countStage(LeadStage stage) =>
      leads.where((lead) => lead.stage == stage).length;

  List<CrmContact> get recentContacts =>
      contacts.take(3).toList(growable: false);

  @override
  List<Object?> get props => [status, contacts, failure, tasks, taskReady];
}
