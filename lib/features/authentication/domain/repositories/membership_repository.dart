import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

abstract interface class MembershipRepository {
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId});
}
