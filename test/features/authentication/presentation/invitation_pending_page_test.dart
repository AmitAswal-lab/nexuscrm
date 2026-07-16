import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/invitation_pending_page.dart';

void main() {
  testWidgets('activates the authenticated user’s matching invitation', (
    tester,
  ) async {
    final repository = _InvitationRepository();
    await _pumpPage(tester, repository);

    await tester.tap(find.text('Activate workspace'));
    await tester.pumpAndSettle();

    expect(repository.acceptedWorkspaceId, 'workspace-one');
    expect(repository.acceptedInvitationId, 'invite-one');
  });

  testWidgets('shows a safe failure when activation is no longer available', (
    tester,
  ) async {
    final repository = _InvitationRepository(
      failure: const InvitationActionFailure(
        InvitationActionFailureCode.expired,
      ),
    );
    await _pumpPage(tester, repository);

    await tester.tap(find.text('Activate workspace'));
    await tester.pumpAndSettle();

    expect(find.text('This invitation has expired.'), findsOneWidget);
  });
}

Future<void> _pumpPage(WidgetTester tester, _InvitationRepository repository) =>
    tester.pumpWidget(
      MaterialApp(
        home: InvitationPendingPage(
          membership: const WorkspaceMembership(
            workspaceId: 'workspace-one',
            userId: 'sales-user',
            role: WorkspaceRole.salesRep,
            status: MembershipStatus.invited,
            invitationId: 'invite-one',
          ),
          invitationRepository: repository,
        ),
      ),
    );

final class _InvitationRepository implements InvitationRepository {
  _InvitationRepository({this.failure});

  final InvitationActionFailure? failure;
  String? acceptedWorkspaceId;
  String? acceptedInvitationId;

  @override
  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    acceptedWorkspaceId = workspaceId;
    acceptedInvitationId = invitationId;
    if (failure != null) throw failure!;
  }

  @override
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  }) => throw UnimplementedError();

  @override
  Future<void> revokeInvitation({
    required String workspaceId,
    required String invitationId,
  }) => throw UnimplementedError();

  @override
  Future<InvitationCreationResult> resendInvitation({
    required String workspaceId,
    required String invitationId,
  }) => throw UnimplementedError();
}
