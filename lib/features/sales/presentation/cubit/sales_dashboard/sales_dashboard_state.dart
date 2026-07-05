part of 'sales_dashboard_cubit.dart';

enum SalesDashboardStatus { loading, success, failure }

final class SalesDashboardState extends Equatable {
  const SalesDashboardState({
    this.status = SalesDashboardStatus.loading,
    this.contacts = const <CrmContact>[],
    this.failure,
  });

  final SalesDashboardStatus status;
  final List<CrmContact> contacts;
  final ContactFailure? failure;

  List<Lead> get leads => contacts.whereType<Lead>().toList(growable: false);

  int get clientCount => contacts.whereType<ClientContact>().length;

  int get pipelineCount =>
      leads.where((lead) => lead.stage != LeadStage.lost).length;

  int countStage(LeadStage stage) =>
      leads.where((lead) => lead.stage == stage).length;

  List<CrmContact> get recentContacts =>
      contacts.take(3).toList(growable: false);

  @override
  List<Object?> get props => [status, contacts, failure];
}
