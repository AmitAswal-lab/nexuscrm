import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_dashboard_page.dart';

void main() {
  testWidgets('renders honest dashboard foundation and quick actions', (
    tester,
  ) async {
    _useSize(tester, const Size(390, 844));
    var leadsOpened = 0;
    var tasksOpened = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: SalesDashboardView(
          userLabel: 'Amit',
          onOpenLeads: () => leadsOpened++,
          onOpenTasks: () => tasksOpened++,
        ),
      ),
    );

    expect(find.text('Sales dashboard'), findsOneWidget);
    expect(find.text('Welcome back, Amit'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('Leads'), findsOneWidget);
    expect(find.text("Today's follow-ups"), findsOneWidget);
    expect(find.text('Overdue tasks'), findsOneWidget);
    expect(find.text('Pipeline'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Recent leads'), findsOneWidget);
    expect(find.textContaining('Available with'), findsNWidgets(4));

    await tester.tap(find.text('Open leads'));
    await tester.tap(find.text('Open tasks'));

    expect(leadsOpened, 1);
    expect(tasksOpened, 1);
  });

  testWidgets(
    'uses a four-column overview and side-by-side sections when wide',
    (tester) async {
      _useSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: SalesDashboardView(
            userLabel: 'Amit',
            onOpenLeads: () {},
            onOpenTasks: () {},
          ),
        ),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      final gridDelegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(gridDelegate.crossAxisCount, 4);
      expect(
        tester.getTopLeft(find.text('Today')).dy,
        tester.getTopLeft(find.text('Recent leads')).dy,
      );
    },
  );

  testWidgets('uses the authenticated display name', (tester) async {
    const user = AuthUser(
      id: 'sales-user',
      email: 'sales@example.com',
      displayName: 'Amit',
    );

    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticationRepository(user),
        membershipRepository: const _MembershipRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Amit'), findsOneWidget);
  });

  testWidgets('falls back to the authenticated email', (tester) async {
    const user = AuthUser(id: 'sales-user', email: 'sales@example.com');

    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: const _AuthenticationRepository(user),
        membershipRepository: const _MembershipRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, sales@example.com'), findsOneWidget);
  });
}

void _useSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

final class _AuthenticationRepository implements AuthenticationRepository {
  const _AuthenticationRepository(this.user);

  final AuthUser user;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthUser?> watchAuthUser() => Stream.value(user);
}

final class _MembershipRepository implements MembershipRepository {
  const _MembershipRepository();

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId}) {
    return Stream.value(const <WorkspaceMembership>[
      WorkspaceMembership(
        workspaceId: 'workspace-one',
        userId: 'sales-user',
        role: WorkspaceRole.salesRep,
        status: MembershipStatus.active,
      ),
    ]);
  }
}
