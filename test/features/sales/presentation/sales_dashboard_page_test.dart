import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/sales/presentation/cubit/sales_dashboard/sales_dashboard_cubit.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_dashboard_page.dart';

import '../../../helpers/empty_contact_repository.dart';

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
          dashboardState: const SalesDashboardState(
            status: SalesDashboardStatus.success,
          ),
          onOpenLeads: () => leadsOpened++,
          onOpenTasks: () => tasksOpened++,
          onOpenContact: (_) {},
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Sales dashboard'), findsOneWidget);
    expect(find.text('Welcome back, Amit'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('…'), findsNWidgets(2));
    expect(find.text('Leads'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text("Today's follow-ups"), findsOneWidget);
    expect(find.text('Overdue tasks'), findsOneWidget);
    expect(find.text('Pipeline stages'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Recent contacts'), findsOneWidget);
    expect(find.text('Open follow-ups due today'), findsOneWidget);
    expect(find.text('Open overdue tasks'), findsOneWidget);

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
            dashboardState: const SalesDashboardState(
              status: SalesDashboardStatus.success,
            ),
            onOpenLeads: () {},
            onOpenTasks: () {},
            onOpenContact: (_) {},
            onRetry: () {},
          ),
        ),
      );

      final grid = tester.widget<GridView>(find.byType(GridView));
      final gridDelegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(gridDelegate.crossAxisCount, 4);
      expect(
        tester.getTopLeft(find.text('Today')).dy,
        closeTo(tester.getTopLeft(find.text('Recent contacts')).dy, 8),
      );
    },
  );

  testWidgets('renders real contact metrics and opens a recent contact', (
    tester,
  ) async {
    _useSize(tester, const Size(390, 1000));
    String? openedContactId;

    await tester.pumpWidget(
      MaterialApp(
        home: SalesDashboardView(
          userLabel: 'Amit',
          dashboardState: SalesDashboardState(
            status: SalesDashboardStatus.success,
            contacts: <CrmContact>[_dashboardLead, _dashboardClient],
          ),
          onOpenLeads: () {},
          onOpenTasks: () {},
          onOpenContact: (contactId) => openedContactId = contactId,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('New: 1'), findsOneWidget);
    expect(find.text('Recent contacts'), findsOneWidget);
    expect(find.text('Dashboard lead'), findsOneWidget);
    expect(find.text('Dashboard client'), findsOneWidget);

    await tester.ensureVisible(find.text('Dashboard lead'));
    await tester.tap(find.text('Dashboard lead'));
    expect(openedContactId, 'dashboard-lead');
  });

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
        contactRepository: const EmptyContactRepository(),
        salesAssigneeRepository: const EmptySalesAssigneeRepository(),
        taskRepository: const EmptyTaskRepository(),
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
        contactRepository: const EmptyContactRepository(),
        salesAssigneeRepository: const EmptySalesAssigneeRepository(),
        taskRepository: const EmptyTaskRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, sales@example.com'), findsOneWidget);
  });
}

final _dashboardTime = DateTime.utc(2026);
final _dashboardLead = Lead(
  id: 'dashboard-lead',
  workspaceId: 'workspace-one',
  fullName: 'Dashboard lead',
  companyName: null,
  email: 'lead@example.com',
  phone: null,
  notes: null,
  ownerId: 'sales-user',
  stage: LeadStage.newLead,
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _dashboardTime,
  updatedAt: _dashboardTime,
);
final _dashboardClient = ClientContact(
  id: 'dashboard-client',
  workspaceId: 'workspace-one',
  fullName: 'Dashboard client',
  companyName: null,
  email: 'client@example.com',
  phone: null,
  notes: null,
  ownerId: 'sales-user',
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _dashboardTime,
  updatedAt: _dashboardTime,
  convertedAt: _dashboardTime,
  convertedByUserId: 'sales-user',
);

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
