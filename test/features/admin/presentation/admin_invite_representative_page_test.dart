import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_invite_representative_page.dart';

void main() {
  testWidgets('validates email before creating an invitation', (tester) async {
    final repository = _InvitationRepository();
    await _pumpPage(tester, repository);

    await tester.tap(find.text('Send invitation'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(repository.createCalls, 0);
  });

  testWidgets('shows a saved email-request failure and supports retrying it', (
    tester,
  ) async {
    final repository = _InvitationRepository(
      results: <InvitationCreationResult>[
        InvitationCreationResult(
          invitationId: 'invite-one',
          email: 'rep@example.com',
          expiresAt: DateTime(2026, 7, 20),
          emailRequestStatus: InvitationEmailRequestResult.failed,
        ),
        InvitationCreationResult(
          invitationId: 'invite-one',
          email: 'rep@example.com',
          expiresAt: DateTime(2026, 7, 20),
          emailRequestStatus: InvitationEmailRequestResult.accepted,
        ),
      ],
    );
    await _pumpPage(tester, repository);

    await tester.enterText(find.byType(TextFormField), 'rep@example.com');
    await tester.tap(find.text('Send invitation'));
    await tester.pumpAndSettle();

    expect(find.text('Email request failed'), findsOneWidget);
    expect(find.text('Retry email'), findsOneWidget);

    await tester.tap(find.text('Retry email'));
    await tester.pumpAndSettle();

    expect(repository.resendCalls, 1);
    expect(find.text('Email request accepted'), findsOneWidget);
  });
}

Future<void> _pumpPage(WidgetTester tester, _InvitationRepository repository) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminInviteRepresentativePage(
            workspaceId: 'workspace-one',
            repository: repository,
          ),
        ),
      ),
    );

final class _InvitationRepository implements InvitationRepository {
  _InvitationRepository({List<InvitationCreationResult>? results})
    : _results = results ?? const <InvitationCreationResult>[];

  final List<InvitationCreationResult> _results;
  int createCalls = 0;
  int resendCalls = 0;

  @override
  Future<InvitationCreationResult> createInvitation({
    required String workspaceId,
    required String email,
  }) async {
    createCalls++;
    return _results[createCalls - 1];
  }

  @override
  Future<void> revokeInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {}

  @override
  Future<InvitationCreationResult> resendInvitation({
    required String workspaceId,
    required String invitationId,
  }) async {
    resendCalls++;
    return _results[createCalls + resendCalls - 1];
  }

  @override
  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
    required String displayName,
  }) async {}
}
