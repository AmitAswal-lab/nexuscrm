import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
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
import 'package:nexuscrm/features/authentication/presentation/pages/sign_in_placeholder_page.dart';
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
          builder: (context, state) => const SignInPlaceholderPage(),
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
          builder: (context, state) => const AdminHomePlaceholder(),
        ),
        GoRoute(
          path: AppRoutes.sales,
          builder: (context, state) => const SalesHomePlaceholder(),
        ),
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
        WorkspaceRole.admin => AppRoutes.admin,
        WorkspaceRole.salesRep => AppRoutes.sales,
      },
    };
  }

  static bool _isAllowedLocation(String location, String destination) {
    if (destination == AppRoutes.admin) {
      return location == AppRoutes.admin || location.startsWith('/admin/');
    }

    if (destination == AppRoutes.sales) {
      return location == AppRoutes.sales || location.startsWith('/sales/');
    }

    return location == destination;
  }

  void dispose() {
    router.dispose();
    _refreshNotifier.dispose();
  }
}
