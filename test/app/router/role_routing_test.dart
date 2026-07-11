import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_home_placeholder.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_dashboard_page.dart';

import '../../helpers/empty_contact_repository.dart';

const _user = AuthUser(id: 'user-one', email: 'user@example.com');

void main() {
  testWidgets('admin phone shell exposes role-specific destinations', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _pumpAuthenticatedApp(tester, membership: _adminMembership);

    final router = GoRouter.of(
      tester.element(find.byType(AdminHomePlaceholder)),
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.adminHome,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(_navigationLabels(tester), <String>[
      'Home',
      'Leads',
      'Tasks',
      'More',
    ]);
    expect(find.text('Admin workspace'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Leads'));
    await tester.pumpAndSettle();
    expect(find.text('Leads & clients'), findsOneWidget);
    expect(find.text('All active contacts in this workspace.'), findsOneWidget);
    expect(_selectedPhoneIndex(tester), 1);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('Workspace tasks'), findsOneWidget);
    expect(
      find.text('Tasks and follow-ups across this workspace.'),
      findsOneWidget,
    );
    expect(_selectedPhoneIndex(tester), 2);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(find.text('Admin more'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Sign out'), findsOneWidget);
    expect(_selectedPhoneIndex(tester), 3);

    router.go(AppRoutes.admin);
    await tester.pumpAndSettle();
    expect(find.byType(AdminHomePlaceholder), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.adminHome,
    );
    expect(_selectedPhoneIndex(tester), 0);
  });

  testWidgets('sales phone shell exposes role-specific destinations', (
    tester,
  ) async {
    _usePhoneSize(tester);
    await _pumpAuthenticatedApp(tester, membership: _salesMembership);

    final router = GoRouter.of(tester.element(find.byType(SalesDashboardPage)));

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.salesHome,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Sales dashboard'), findsOneWidget);
    expect(find.text('Welcome back, user@example.com'), findsOneWidget);
    expect(_navigationLabels(tester), <String>[
      'Home',
      'Leads',
      'Tasks',
      'More',
    ]);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Leads'));
    await tester.pumpAndSettle();
    expect(find.text('Leads & clients'), findsOneWidget);
    expect(find.text('Contacts currently assigned to you.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Tasks'));
    await tester.pumpAndSettle();
    expect(find.text('My tasks'), findsOneWidget);
    expect(find.text('Tasks and follow-ups assigned to you.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Account and additional sales tools will appear here in future '
        'milestones.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, 'Sign out'), findsOneWidget);

    router.go(AppRoutes.sales);
    await tester.pumpAndSettle();
    expect(find.byType(SalesDashboardPage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.salesHome,
    );
  });

  testWidgets('wide authenticated layout uses a navigation rail', (
    tester,
  ) async {
    _useWideSize(tester);
    await _pumpAuthenticatedApp(tester, membership: _adminMembership);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(
      rail.destinations.map((destination) => (destination.label as Text).data),
      <String>['Home', 'Leads', 'Tasks', 'More'],
    );

    await tester.tap(find.text('Leads'));
    await tester.pumpAndSettle();
    expect(find.text('Leads & clients'), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
  });

  testWidgets('sign-out is available from More and returns to sign-in', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final authenticationRepository = _ControllableAuthenticationRepository();
    addTearDown(authenticationRepository.close);

    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: authenticationRepository,
        membershipRepository: const _MembershipRepository(<WorkspaceMembership>[
          _adminMembership,
        ]),
        contactRepository: const EmptyContactRepository(),
        salesAssigneeRepository: const EmptySalesAssigneeRepository(),
        taskRepository: const EmptyTaskRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Sign out'));
    await tester.pumpAndSettle();

    expect(authenticationRepository.signOutCalls, 1);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
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
        contactRepository: const EmptyContactRepository(),
        salesAssigneeRepository: const EmptySalesAssigneeRepository(),
        taskRepository: const EmptyTaskRepository(),
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
    _usePhoneSize(tester);
    await _pumpAuthenticatedApp(tester, membership: _adminMembership);

    final router = GoRouter.of(
      tester.element(find.byType(AdminHomePlaceholder)),
    )..go(AppRoutes.salesTasks);
    await tester.pumpAndSettle();

    expect(find.byType(AdminHomePlaceholder), findsOneWidget);
    expect(find.byType(SalesDashboardPage), findsNothing);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.adminHome,
    );
  });
}

Future<void> _pumpAuthenticatedApp(
  WidgetTester tester, {
  required WorkspaceMembership membership,
}) async {
  await tester.pumpWidget(
    NexusCrmApp(
      authenticationRepository: const _AuthenticatedRepository(),
      membershipRepository: _MembershipRepository(<WorkspaceMembership>[
        membership,
      ]),
      contactRepository: const EmptyContactRepository(),
      salesAssigneeRepository: const EmptySalesAssigneeRepository(),
      taskRepository: const EmptyTaskRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _useWideSize(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

List<String> _navigationLabels(WidgetTester tester) {
  final navigationBar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );

  return navigationBar.destinations
      .cast<NavigationDestination>()
      .map((destination) => destination.label)
      .toList(growable: false);
}

int _selectedPhoneIndex(WidgetTester tester) {
  return tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
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

final class _ControllableAuthenticationRepository
    implements AuthenticationRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  int signOutCalls = 0;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _controller.add(null);
  }

  @override
  Stream<AuthUser?> watchAuthUser() async* {
    yield _user;
    yield* _controller.stream;
  }

  Future<void> close() => _controller.close();
}

final class _MembershipRepository implements MembershipRepository {
  const _MembershipRepository(this.memberships);

  final List<WorkspaceMembership> memberships;

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId}) {
    return Stream.value(memberships);
  }
}
