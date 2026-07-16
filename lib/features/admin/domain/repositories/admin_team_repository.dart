import 'package:nexuscrm/features/admin/domain/entities/team_member.dart';

abstract interface class AdminTeamRepository {
  Stream<List<TeamMember>> watchTeam({required String workspaceId});
}
