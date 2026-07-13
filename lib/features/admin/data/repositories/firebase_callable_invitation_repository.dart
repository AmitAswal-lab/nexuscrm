import 'package:cloud_functions/cloud_functions.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';

final class FirebaseCallableInvitationRepository
    implements InvitationRepository {
  FirebaseCallableInvitationRepository(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  }) async {
    final result = await _functions
        .httpsCallable('createWorkspaceInvitation')
        .call(<String, Object>{'workspaceId': workspaceId, 'email': email});

    return InvitationCreationResult.fromCallableData(result.data);
  }
}
