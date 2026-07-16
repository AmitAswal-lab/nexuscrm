import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

abstract interface class MembershipManagementRepository {
  Future<void> updateSalesRepresentativeStatus({
    required String workspaceId,
    required String userId,
    required MembershipStatus status,
  });
}
