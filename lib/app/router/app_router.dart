import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nexuscrm/app/navigation/app_navigation_shell.dart';
import 'package:nexuscrm/app/navigation/pages/more_page.dart';
import 'package:nexuscrm/app/router/app_routes.dart';
import 'package:nexuscrm/app/router/router_refresh_notifier.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/activities/presentation/cubit/call_note_form/call_note_form_cubit.dart';
import 'package:nexuscrm/features/activities/presentation/pages/call_note_form_page.dart';
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
import 'package:nexuscrm/features/sales/presentation/cubit/sales_dashboard/sales_dashboard_cubit.dart';
import 'package:nexuscrm/features/sales/presentation/pages/sales_dashboard_page.dart';
import 'package:nexuscrm/features/tasks/domain/repositories/task_repository.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_detail/task_detail_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_form/task_form_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/cubit/task_list/task_list_cubit.dart';
import 'package:nexuscrm/features/tasks/presentation/pages/task_detail_page.dart';
import 'package:nexuscrm/features/tasks/presentation/pages/task_form_page.dart';
import 'package:nexuscrm/features/tasks/presentation/pages/task_list_page.dart';

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
                    newTaskRoute: AppRoutes.adminNewTask,
                    logCallNoteRoute: AppRoutes.adminLogCallNote,
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
                    GoRoute(
                      path: 'call-note',
                      builder: (context, state) => _callNoteFormPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
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
              builder: (context, state) => _taskListPage(
                context,
                title: 'Workspace tasks',
                description: 'Tasks and follow-ups across this workspace.',
                accessScope: const WorkspaceTaskAccess(),
                showAssignee: true,
                newRoute: AppRoutes.adminNewTask,
                taskRoute: AppRoutes.adminTask,
              ),
              routes: _taskRoutes(
                canAssign: true,
                editRoute: AppRoutes.adminEditTask,
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
              builder: (context, state) => _salesDashboardPage(context),
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
                    newTaskRoute: AppRoutes.salesNewTask,
                    logCallNoteRoute: AppRoutes.salesLogCallNote,
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
                    GoRoute(
                      path: 'call-note',
                      builder: (context, state) => _callNoteFormPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
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
              builder: (context, state) {
                final session = _authenticatedSession(context);

                return _taskListPage(
                  context,
                  title: 'My tasks',
                  description: 'Tasks and follow-ups assigned to you.',
                  accessScope: AssignedTaskAccess(session.user.id),
                  showAssignee: false,
                  newRoute: AppRoutes.salesNewTask,
                  taskRoute: AppRoutes.salesTask,
                );
              },
              routes: _taskRoutes(
                canAssign: false,
                editRoute: AppRoutes.salesEditTask,
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

  static Widget _salesDashboardPage(BuildContext context) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => SalesDashboardCubit(
        contactRepository: context.read<ContactRepository>(),
        workspaceId: session.membership.workspaceId,
        ownerId: session.user.id,
        taskRepository: context.read<TaskRepository>(),
      ),
      child: const SalesDashboardPage(),
    );
  }

  static Widget _taskListPage(
    BuildContext context, {
    required String title,
    required String description,
    required TaskAccessScope accessScope,
    required bool showAssignee,
    required String newRoute,
    required String Function(String) taskRoute,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => TaskListCubit(
        taskRepository: context.read<TaskRepository>(),
        workspaceId: session.membership.workspaceId,
        accessScope: accessScope,
      ),
      child: TaskListPage(
        title: title,
        description: description,
        showAssignee: showAssignee,
        onCreateTask: () => context.go(newRoute),
        onOpenTask: (id) => context.go(taskRoute(id)),
        workspaceId: session.membership.workspaceId,
        assigneeRepository: context.read<SalesAssigneeRepository>(),
      ),
    );
  }

  static List<RouteBase> _taskRoutes({
    required bool canAssign,
    required String Function(String) editRoute,
  }) => [
    GoRoute(
      path: 'new',
      builder: (context, state) => _taskFormPage(
        context,
        canAssign: canAssign,
        initialContactId: state.uri.queryParameters['contactId'],
      ),
    ),
    GoRoute(
      path: ':taskId',
      builder: (context, state) => _taskDetailPage(
        context,
        taskId: state.pathParameters['taskId']!,
        editRoute: editRoute,
      ),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) => _taskFormPage(
            context,
            canAssign: canAssign,
            taskId: state.pathParameters['taskId']!,
          ),
        ),
      ],
    ),
  ];

  static Widget _taskFormPage(
    BuildContext context, {
    required bool canAssign,
    String? taskId,
    String? initialContactId,
  }) {
    final session = _authenticatedSession(context);
    return BlocProvider(
      create: (context) => TaskFormCubit(
        taskRepository: context.read<TaskRepository>(),
        contactRepository: context.read<ContactRepository>(),
        salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
        workspaceId: session.membership.workspaceId,
        actorUserId: session.user.id,
        contactAccessScope: canAssign
            ? const WorkspaceContactAccess()
            : OwnedContactAccess(session.user.id),
        canAssign: canAssign,
        fixedAssigneeId: canAssign ? null : session.user.id,
        taskId: taskId,
      ),
      child: TaskFormPage(
        canAssign: canAssign,
        initialContactId: initialContactId,
      ),
    );
  }

  static Widget _taskDetailPage(
    BuildContext context, {
    required String taskId,
    required String Function(String) editRoute,
  }) {
    final session = _authenticatedSession(context);
    return BlocProvider(
      create: (context) => TaskDetailCubit(
        taskRepository: context.read<TaskRepository>(),
        workspaceId: session.membership.workspaceId,
        taskId: taskId,
        actorUserId: session.user.id,
      ),
      child: TaskDetailPage(
        onEdit: () => context.go(editRoute(taskId)),
        workspaceId: session.membership.workspaceId,
        contactRepository: context.read<ContactRepository>(),
        assigneeRepository: context.read<SalesAssigneeRepository>(),
      ),
    );
  }

  static Widget _contactDetailPage(
    BuildContext context, {
    required String contactId,
    required bool isSalesView,
    required String Function(String) editRoute,
    required String newTaskRoute,
    required String Function(String) logCallNoteRoute,
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
        onAddFollowUp: () => context.go('$newTaskRoute?contactId=$contactId'),
        onLogCallNote: () => context.go(logCallNoteRoute(contactId)),
        workspaceId: session.membership.workspaceId,
        taskAccessScope: isSalesView
            ? AssignedTaskAccess(session.user.id)
            : const WorkspaceTaskAccess(),
        taskRepository: context.read<TaskRepository>(),
      ),
    );
  }

  static Widget _callNoteFormPage(
    BuildContext context, {
    required String contactId,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => CallNoteFormCubit(
        activityRepository: context.read<ActivityRepository>(),
        workspaceId: session.membership.workspaceId,
        contactId: contactId,
        actorUserId: session.user.id,
      ),
      child: const CallNoteFormPage(),
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
