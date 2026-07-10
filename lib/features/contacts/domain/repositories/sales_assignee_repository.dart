import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';

abstract interface class SalesAssigneeRepository {
  Stream<List<SalesAssignee>> watchActiveSalesAssignees({
    required String workspaceId,
  });
}
