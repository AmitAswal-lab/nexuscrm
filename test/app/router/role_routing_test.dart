import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_home_placeholder.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_home_placeholder.dart';

const _user = AuthUser(id: 'user-one', email: 'user@example.com');

void main() {
  testWidgets('routes an admin to the admin destination', (tester) async {
    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticatedRepository(),
        membershipRepository: const _MembershipRepository(<WorkspaceMembership>[
          _adminMembership,
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Admin workspace'), findsOneWidget);
    expect(find.byType(AdminHomePlaceholder), findsOneWidget);
  });

  testWidgets('routes a sales rep to the sales destination', (tester) async {
    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticatedRepository(),
        membershipRepository: const _MembershipRepository(<WorkspaceMembership>[
          _salesMembership,
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sales workspace'), findsOneWidget);
    expect(find.byType(SalesHomePlaceholder), findsOneWidget);
  });

  testWidgets('routes a user without membership to access denied', (
    tester,
  ) async {
    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticatedRepository(),
        membershipRepository: const _MembershipRepository(
          <WorkspaceMembership>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Access unavailable'), findsOneWidget);
    expect(
      find.text('Your account does not have access to a workspace.'),
      findsOneWidget,
    );
  });

  testWidgets('prevents an admin from entering sales routes', (tester) async {
    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticatedRepository(),
        membershipRepository: const _MembershipRepository(<WorkspaceMembership>[
          _adminMembership,
        ]),
      ),
    );
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(AdminHomePlaceholder))).go('/sales');
    await tester.pumpAndSettle();

    expect(find.byType(AdminHomePlaceholder), findsOneWidget);
    expect(find.byType(SalesHomePlaceholder), findsNothing);
  });
}

const _adminMembership = WorkspaceMembership(
  workspaceId: 'workspace-one',
  userId: 'user-one',
  role: WorkspaceRole.admin,
  status: MembershipStatus.active,
);

const _salesMembership = WorkspaceMembership(
  workspaceId: 'workspace-one',
  userId: 'user-one',
  role: WorkspaceRole.salesRep,
  status: MembershipStatus.active,
);

final class _AuthenticatedRepository implements AuthenticationRepository {
  const _AuthenticatedRepository();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthUser?> watchAuthUser() => Stream.value(_user);
}

final class _MembershipRepository implements MembershipRepository {
  const _MembershipRepository(this.memberships);

  final List<WorkspaceMembership> memberships;

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId}) {
    return Stream.value(memberships);
  }
}
