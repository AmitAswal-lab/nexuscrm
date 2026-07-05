import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/navigation/app_navigation_shell.dart';
import 'package:nexuscrm/app/navigation/pages/more_page.dart';
import 'package:nexuscrm/app/navigation/pages/navigation_placeholder_page.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/app/router/router_refresh_notifier.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_home_placeholder.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_session.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/access_denied_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/configuration_error_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/invitation_pending_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/session_error_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/session_loading_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_actions/contact_actions_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_edit/contact_edit_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_list/contact_list_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/lead_form/lead_form_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_edit_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_list_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/lead_form_page.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_dashboard_page.dart';

final class AppRouter {
  AppRouter(this._sessionBloc)
    : _refreshNotifier = RouterRefreshNotifier(_sessionBloc.stream) {
    router = GoRouter(
      initialLocation: AppRoutes.loading,
      refreshListenable: _refreshNotifier,
      redirect: _redirect,
      routes: [
        GoRoute(
          path: AppRoutes.loading,
          builder: (context, state) => const SessionLoadingPage(),
        ),
        GoRoute(
          path: AppRoutes.signIn,
          builder: (context, state) => const SignInPage(),
        ),
        GoRoute(
          path: AppRoutes.invitationPending,
          builder: (context, state) => const InvitationPendingPage(),
        ),
        GoRoute(
          path: AppRoutes.accessDenied,
          builder: (context, state) {
            final sessionState = _sessionBloc.state;
            final reason = sessionState is SessionAccessDenied
                ? sessionState.reason
                : SessionAccessDeniedReason.noMembership;

            return AccessDeniedPage(reason: reason);
          },
        ),
        GoRoute(
          path: AppRoutes.configurationError,
          builder: (context, state) {
            final sessionState = _sessionBloc.state;
            final reason = sessionState is SessionConfigurationError
                ? sessionState.reason
                : SessionConfigurationErrorReason.multipleActiveMemberships;

            return ConfigurationErrorPage(reason: reason);
          },
        ),
        GoRoute(
          path: AppRoutes.error,
          builder: (context, state) => const SessionErrorPage(),
        ),
        GoRoute(
          path: AppRoutes.admin,
          redirect: (context, state) => AppRoutes.adminHome,
        ),
        _adminShellRoute(),
        GoRoute(
          path: AppRoutes.sales,
          redirect: (context, state) => AppRoutes.salesHome,
        ),
        _salesShellRoute(),
      ],
    );
  }

  final SessionBloc _sessionBloc;
  final RouterRefreshNotifier _refreshNotifier;
  late final GoRouter router;

  String? _redirect(BuildContext context, GoRouterState routerState) {
    final destination = _destinationFor(_sessionBloc.state);
    final location = routerState.uri.path;

    if (_isAllowedLocation(location, destination)) {
      return null;
    }

    return destination;
  }

  static String _destinationFor(SessionState state) {
    return switch (state) {
      SessionInitial() || SessionResolvingAccess() => AppRoutes.loading,
      SessionUnauthenticated() => AppRoutes.signIn,
      SessionInvitationPending() => AppRoutes.invitationPending,
      SessionAccessDenied() => AppRoutes.accessDenied,
      SessionConfigurationError() => AppRoutes.configurationError,
      SessionFailure() => AppRoutes.error,
      SessionAuthenticated(:final session) => switch (session.membership.role) {
        WorkspaceRole.admin => AppRoutes.adminHome,
        WorkspaceRole.salesRep => AppRoutes.salesHome,
      },
    };
  }

  static bool _isAllowedLocation(String location, String destination) {
    if (destination == AppRoutes.adminHome) {
      return location == AppRoutes.admin || location.startsWith('/admin/');
    }

    if (destination == AppRoutes.salesHome) {
      return location == AppRoutes.sales || location.startsWith('/sales/');
    }

    return location == destination;
  }

  static StatefulShellRoute _adminShellRoute() {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppNavigationShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminHome,
              builder: (context, state) => const AdminHomePlaceholder(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminLeads,
              builder: (context, state) => _contactListPage(
                context,
                accessScope: const WorkspaceContactAccess(),
                title: 'Leads & clients',
                description: 'All active contacts in this workspace.',
                createLeadRoute: AppRoutes.adminNewLead,
                contactRoute: AppRoutes.adminContact,
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) =>
                      _leadFormPage(context, canAssignOwner: true),
                ),
                GoRoute(
                  path: ':contactId',
                  builder: (context, state) => _contactDetailPage(
                    context,
                    contactId: state.pathParameters['contactId']!,
                    isSalesView: false,
                    editRoute: AppRoutes.adminEditContact,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => _contactEditPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
                        canAssignOwner: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminTasks,
              builder: (context, state) => const NavigationPlaceholderPage(
                icon: Icons.fact_check_outlined,
                title: 'Workspace tasks',
                message:
                    'Administrator task oversight is planned for a later '
                    'milestone.',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminMore,
              builder: (context, state) => const MorePage(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Admin more',
                message:
                    'Team management and activity reporting will appear here '
                    'in future milestones.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static StatefulShellRoute _salesShellRoute() {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppNavigationShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.salesHome,
              builder: (context, state) => const SalesDashboardPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.salesLeads,
              builder: (context, state) {
                final session = _authenticatedSession(context);

                return _contactListPage(
                  context,
                  accessScope: OwnedContactAccess(session.user.id),
                  title: 'Leads & clients',
                  description: 'Contacts currently assigned to you.',
                  createLeadRoute: AppRoutes.salesNewLead,
                  contactRoute: AppRoutes.salesContact,
                );
              },
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) =>
                      _leadFormPage(context, canAssignOwner: false),
                ),
                GoRoute(
                  path: ':contactId',
                  builder: (context, state) => _contactDetailPage(
                    context,
                    contactId: state.pathParameters['contactId']!,
                    isSalesView: true,
                    editRoute: AppRoutes.salesEditContact,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => _contactEditPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
                        canAssignOwner: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.salesTasks,
              builder: (context, state) => const NavigationPlaceholderPage(
                icon: Icons.task_alt,
                title: 'My tasks',
                message:
                    'Tasks and follow-ups are planned for a later milestone.',
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.salesMore,
              builder: (context, state) => const MorePage(
                icon: Icons.person_outline,
                title: 'More',
                message:
                    'Account and additional sales tools will appear here in '
                    'future milestones.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _contactListPage(
    BuildContext context, {
    required ContactAccessScope accessScope,
    required String title,
    required String description,
    required String createLeadRoute,
    required String Function(String) contactRoute,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => ContactListCubit(
        contactRepository: context.read<ContactRepository>(),
        workspaceId: session.membership.workspaceId,
        accessScope: accessScope,
      ),
      child: ContactListPage(
        title: title,
        description: description,
        onCreateLead: () => context.go(createLeadRoute),
        onOpenContact: (contactId) => context.go(contactRoute(contactId)),
      ),
    );
  }

  static Widget _contactDetailPage(
    BuildContext context, {
    required String contactId,
    required bool isSalesView,
    required String Function(String) editRoute,
  }) {
    final session = _authenticatedSession(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ContactDetailCubit(
            contactRepository: context.read<ContactRepository>(),
            workspaceId: session.membership.workspaceId,
            contactId: contactId,
          ),
        ),
        BlocProvider(
          create: (context) => ContactActionsCubit(
            contactRepository: context.read<ContactRepository>(),
            workspaceId: session.membership.workspaceId,
            contactId: contactId,
            actorUserId: session.user.id,
          ),
        ),
      ],
      child: ContactDetailPage(
        isSalesView: isSalesView,
        onEdit: () => context.go(editRoute(contactId)),
      ),
    );
  }

  static Widget _contactEditPage(
    BuildContext context, {
    required String contactId,
    required bool canAssignOwner,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => ContactEditCubit(
        contactRepository: context.read<ContactRepository>(),
        salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
        workspaceId: session.membership.workspaceId,
        contactId: contactId,
        actorUserId: session.user.id,
        requiresAssigneeDirectory: canAssignOwner,
        fixedOwnerId: canAssignOwner ? null : session.user.id,
      ),
      child: ContactEditPage(canAssignOwner: canAssignOwner),
    );
  }

  static Widget _leadFormPage(
    BuildContext context, {
    required bool canAssignOwner,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => LeadFormCubit(
        contactRepository: context.read<ContactRepository>(),
        salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
        workspaceId: session.membership.workspaceId,
        actorUserId: session.user.id,
        requiresAssigneeDirectory: canAssignOwner,
        fixedOwnerId: canAssignOwner ? null : session.user.id,
      ),
      child: LeadFormPage(canAssignOwner: canAssignOwner),
    );
  }

  static AuthSession _authenticatedSession(BuildContext context) {
    final state = context.read<SessionBloc>().state;

    if (state is! SessionAuthenticated) {
      throw StateError('Contact routes require an authenticated session.');
    }

    return state.session;
  }

  void dispose() {
    router.dispose();
    _refreshNotifier.dispose();
  }
}
