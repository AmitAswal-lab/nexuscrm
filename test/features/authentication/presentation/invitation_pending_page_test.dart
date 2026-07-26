import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';
import 'package:nexuscrm/features/admin/domain/failures/invitation_action_failure.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/invitation_pending_page.dart';

void main() {
  testWidgets(
    'shows an in-flight state and then waits for the sales transition',
    (tester) async {
      final completion = Completer<void>();
      final repository = _InvitationRepository(completion: completion);
      await _pumpPage(tester, repository);

      await tester.tap(find.text('Activate workspace'));
      await tester.pump();

      expect(repository.acceptCallCount, 1);
      expect(find.text('Activating workspace…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(
                TextButton,
                'Sign out and use a different account',
              ),
            )
            .onPressed,
        isNull,
      );

      completion.complete();
      await tester.pumpAndSettle();

      expect(repository.acceptedWorkspaceId, 'workspace-one');
      expect(repository.acceptedInvitationId, 'invite-one');
      expect(
        find.text('Workspace activated. Opening your sales workspace…'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    },
  );

  testWidgets('allows a safe retry only after a temporary availability failure', (
    tester,
  ) async {
    final repository = _InvitationRepository(
      outcomes: const [
        InvitationActionFailure(InvitationActionFailureCode.unavailable),
        null,
      ],
    );
    await _pumpPage(tester, repository);

    await tester.tap(find.text('Activate workspace'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Workspace activation is temporarily unavailable. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.acceptCallCount, 2);
    expect(
      find.text('Workspace activated. Opening your sales workspace…'),
      findsOneWidget,
    );
  });

  testWidgets(
    'does not retry an expired invitation and offers sign-out recovery',
    (tester) async {
      final repository = _InvitationRepository(
        outcomes: const [
          InvitationActionFailure(InvitationActionFailureCode.expired),
        ],
      );
      await _pumpPage(tester, repository);

      await tester.tap(find.text('Activate workspace'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This invitation has expired. Ask an administrator to send a new one.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Activation unavailable'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        find.widgetWithText(TextButton, 'Sign out and use a different account'),
        findsOneWidget,
      );
    },
  );

  testWidgets('falls back to a safe error state for an unexpected failure', (
    tester,
  ) async {
    final repository = _InvitationRepository(
      outcomes: [StateError('unexpected')],
    );
    await _pumpPage(tester, repository);

    await tester.tap(find.text('Activate workspace'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This invitation can no longer be activated. Contact an administrator for help.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets(
    'signs out for account recovery without activating the invitation',
    (tester) async {
      final authenticationRepository = _AuthenticationRepository();
      final sessionBloc = SessionBloc(
        authenticationRepository: authenticationRepository,
        membershipRepository: const _MembershipRepository(),
      );
      addTearDown(sessionBloc.close);
      final repository = _InvitationRepository();
      await _pumpPage(tester, repository, sessionBloc: sessionBloc);

      await tester.tap(find.text('Sign out and use a different account'));
      await tester.pumpAndSettle();

      expect(authenticationRepository.signOutCalls, 1);
      expect(repository.acceptCallCount, 0);
    },
  );

  testWidgets('cannot activate without a name and sends it trimmed', (
    tester,
  ) async {
    final repository = _InvitationRepository();
    await _pumpPage(tester, repository, name: null);

    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '  Priya Sharma  ');
    await tester.pump();
    await tester.tap(find.text('Activate workspace'));
    await tester.pumpAndSettle();

    expect(repository.acceptCallCount, 1);
    expect(repository.acceptedDisplayName, 'Priya Sharma');
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _InvitationRepository repository, {
  SessionBloc? sessionBloc,
  String? name = 'Priya Sharma',
}) async {
  final page = InvitationPendingPage(
    membership: const WorkspaceMembership(
      workspaceId: 'workspace-one',
      userId: 'sales-user',
      role: WorkspaceRole.salesRep,
      status: MembershipStatus.invited,
      invitationId: 'invite-one',
    ),
    invitationRepository: repository,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: sessionBloc == null
          ? page
          : BlocProvider.value(value: sessionBloc, child: page),
    ),
  );

  if (name != null) {
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
  }
}

final class _InvitationRepository implements InvitationRepository {
  _InvitationRepository({this.outcomes = const [], this.completion});

  final List<Object?> outcomes;
  final Completer<void>? completion;
  String? acceptedWorkspaceId;
  String? acceptedInvitationId;
  String? acceptedDisplayName;
  int acceptCallCount = 0;

  @override
  Future<void> acceptInvitation({
    required String workspaceId,
    required String invitationId,
    required String displayName,
  }) async {
    acceptedWorkspaceId = workspaceId;
    acceptedInvitationId = invitationId;
    acceptedDisplayName = displayName;
    final outcome = acceptCallCount < outcomes.length
        ? outcomes[acceptCallCount]
        : null;
    acceptCallCount++;
    await completion?.future;
    if (outcome != null) throw outcome;
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

final class _AuthenticationRepository implements AuthenticationRepository {
  int signOutCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Stream<AuthUser?> watchAuthUser() => const Stream.empty();
}

final class _MembershipRepository implements MembershipRepository {
  const _MembershipRepository();

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({
    required String userId,
  }) => const Stream.empty();
}
