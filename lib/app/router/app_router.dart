import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/navigation/app_navigation_shell.dart';
import 'package:nexuscrm/app/navigation/pages/more_page.dart';
import 'package:nexuscrm/app/navigation/pages/navigation_placeholder_page.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/app/router/router_refresh_notifier.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_home_placeholder.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/access_denied_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/configuration_error_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/invitation_pending_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/session_error_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/session_loading_page.dart';
import 'package:nexuscrm/features/authentication/presentation/pages/sign_in_page.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_home_placeholder.dart';

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
              builder: (context, state) => const NavigationPlaceholderPage(
                icon: Icons.groups_outlined,
                title: 'Workspace leads',
                message:
                    'Administrator lead and client management is planned for '
                    'a later milestone.',
              ),
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
              builder: (context, state) => const SalesHomePlaceholder(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.salesLeads,
              builder: (context, state) => const NavigationPlaceholderPage(
                icon: Icons.person_search_outlined,
                title: 'My leads',
                message:
                    'Sales lead and client management is planned for a later '
                    'milestone.',
              ),
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

  void dispose() {
    router.dispose();
    _refreshNotifier.dispose();
  }
}
