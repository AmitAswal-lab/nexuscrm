import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:nexuscrm/features/admin/data/repositories/firebase_callable_invitation_repository.dart';
import 'package:nexuscrm/features/admin/data/repositories/firebase_callable_membership_management_repository.dart';
import 'package:nexuscrm/features/admin/data/repositories/firestore_admin_team_repository.dart';
import 'package:nexuscrm/features/admin/data/repositories/firestore_invitation_directory_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/admin_team_repository.dart';
import 'package:nexuscrm/features/admin/domain/repositories/invitation_repository.dart';
import 'package:nexuscrm/features/admin/presentation/cubit/activity_overview/activity_overview_cubit.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_activity_page.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_invite_representative_page.dart';
import 'package:nexuscrm/features/admin/presentation/pages/admin_team_directory_page.dart';
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
import 'package:nexuscrm/features/contacts/presentation/cubit/archived_contacts/archived_contacts_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_actions/contact_actions_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_edit/contact_edit_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_list/contact_list_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/lead_form/lead_form_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/archived_contacts_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_activity_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_edit_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_list_page.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/lead_form_page.dart';
import 'package:nexuscrm/features/documents/domain/repositories/document_repository.dart';
import 'package:nexuscrm/features/documents/domain/services/share_launcher.dart';
import 'package:nexuscrm/features/documents/presentation/cubit/contact_share/contact_share_cubit.dart';
import 'package:nexuscrm/features/documents/presentation/cubit/document_library/document_library_cubit.dart';
import 'package:nexuscrm/features/documents/presentation/pages/contact_share_page.dart';
import 'package:nexuscrm/features/documents/presentation/pages/document_library_page.dart';
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
  AppRouter(this._sessionBloc, {InvitationRepository? invitationRepository})
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
          builder: (context, state) {
            final sessionState = _sessionBloc.state;
            if (sessionState is! SessionInvitationPending) {
              return const SessionLoadingPage();
            }
            return InvitationPendingPage(
              membership: sessionState.membership,
              invitationRepository:
                  invitationRepository ??
                  FirebaseCallableInvitationRepository(
                    FirebaseFunctions.instance,
                  ),
            );
          },
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
              builder: (context, state) => _adminActivityPage(context),
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
                archivedRoute: AppRoutes.adminArchivedContacts,
              ),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) =>
                      _leadFormPage(context, canAssignOwner: true),
                ),
                GoRoute(
                  path: 'archived',
                  builder: (context, state) => _archivedContactsPage(
                    context,
                    accessScope: const WorkspaceContactAccess(),
                  ),
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
                    activityRoute: AppRoutes.adminContactActivity,
                    shareRoute: AppRoutes.adminContactShare,
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
                        canAssignFollowUp: true,
                      ),
                    ),
                    GoRoute(
                      path: 'activity',
                      builder: (context, state) => _contactActivityPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
                        isSalesView: false,
                      ),
                    ),
                    GoRoute(
                      path: 'share',
                      builder: (context, state) => _contactSharePage(
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
                isSalesView: false,
                editRoute: AppRoutes.adminEditTask,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adminMore,
              builder: (context, state) => MorePage(
                icon: Icons.admin_panel_settings_outlined,
                title: 'More',
                message: 'Workspace administration and account settings.',
                additionalActions: [
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: const Text('Team'),
                    subtitle: const Text(
                      'View workspace representatives and access states',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.adminTeam),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder_shared_outlined),
                    title: const Text('Documents'),
                    subtitle: const Text(
                      'Publish files representatives may send to contacts',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.adminDocuments),
                  ),
                ],
              ),
              routes: [
                GoRoute(
                  path: 'team',
                  builder: (context, state) {
                    final session = _authenticatedSession(context);
                    return AdminTeamDirectoryPage(
                      workspaceId: session.membership.workspaceId,
                      teamRepository: FirestoreAdminTeamRepository(
                        FirebaseFirestore.instance,
                      ),
                      invitationDirectoryRepository:
                          FirestoreInvitationDirectoryRepository(
                            FirebaseFirestore.instance,
                          ),
                      invitationRepository:
                          FirebaseCallableInvitationRepository(
                            FirebaseFunctions.instance,
                          ),
                      membershipManagementRepository:
                          FirebaseCallableMembershipManagementRepository(
                            FirebaseFunctions.instance,
                          ),
                      onInvite: () =>
                          context.push(AppRoutes.adminInviteRepresentative),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'invite',
                      builder: (context, state) {
                        final session = _authenticatedSession(context);
                        return AdminInviteRepresentativePage(
                          workspaceId: session.membership.workspaceId,
                          repository: FirebaseCallableInvitationRepository(
                            FirebaseFunctions.instance,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.adminDocuments,
              builder: (context, state) => _documentLibraryPage(context),
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
                  archivedRoute: AppRoutes.salesArchivedContacts,
                );
              },
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) =>
                      _leadFormPage(context, canAssignOwner: false),
                ),
                GoRoute(
                  path: 'archived',
                  builder: (context, state) {
                    final session = _authenticatedSession(context);

                    return _archivedContactsPage(
                      context,
                      accessScope: OwnedContactAccess(session.user.id),
                    );
                  },
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
                    activityRoute: AppRoutes.salesContactActivity,
                    shareRoute: AppRoutes.salesContactShare,
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
                        canAssignFollowUp: false,
                      ),
                    ),
                    GoRoute(
                      path: 'activity',
                      builder: (context, state) => _contactActivityPage(
                        context,
                        contactId: state.pathParameters['contactId']!,
                        isSalesView: true,
                      ),
                    ),
                    GoRoute(
                      path: 'share',
                      builder: (context, state) => _contactSharePage(
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
                isSalesView: true,
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
                message: 'Your account and workspace access.',
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
    required String archivedRoute,
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
        onOpenArchived: () => context.go(archivedRoute),
      ),
    );
  }

  static Widget _documentLibraryPage(BuildContext context) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => DocumentLibraryCubit(
        documentRepository: context.read<DocumentRepository>(),
        workspaceId: session.membership.workspaceId,
        actorUserId: session.user.id,
      ),
      child: const DocumentLibraryPage(),
    );
  }

  static Widget _contactSharePage(
    BuildContext context, {
    required String contactId,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => ContactDetailCubit(
        contactRepository: context.read<ContactRepository>(),
        workspaceId: session.membership.workspaceId,
        contactId: contactId,
      ),
      child: BlocBuilder<ContactDetailCubit, ContactDetailState>(
        builder: (context, state) {
          final contact = state.contact;

          if (contact == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return BlocProvider(
            create: (context) => ContactShareCubit(
              documentRepository: context.read<DocumentRepository>(),
              shareLauncher: context.read<ShareLauncher>(),
              workspaceId: session.membership.workspaceId,
              actorUserId: session.user.id,
              contact: contact,
            ),
            child: const ContactSharePage(),
          );
        },
      ),
    );
  }

  static Widget _archivedContactsPage(
    BuildContext context, {
    required ContactAccessScope accessScope,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => ArchivedContactsCubit(
        contactRepository: context.read<ContactRepository>(),
        workspaceId: session.membership.workspaceId,
        accessScope: accessScope,
        actorUserId: session.user.id,
      ),
      child: const ArchivedContactsPage(),
    );
  }

  static Widget _adminActivityPage(BuildContext context) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => ActivityOverviewCubit(
        activityRepository: context.read<ActivityRepository>(),
        workspaceId: session.membership.workspaceId,
      ),
      child: AdminActivityPage(
        workspaceId: session.membership.workspaceId,
        teamRepository: context.read<AdminTeamRepository>(),
        activityRepository: context.read<ActivityRepository>(),
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
        teamRepository: context.read<AdminTeamRepository>(),
      ),
    );
  }

  static List<RouteBase> _taskRoutes({
    required bool canAssign,
    required bool isSalesView,
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
        isSalesView: isSalesView,
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
    required bool isSalesView,
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
        teamRepository: context.read<AdminTeamRepository>(),
        isSalesView: isSalesView,
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
    required String Function(String) activityRoute,
    required String Function(String) shareRoute,
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
        onViewAllActivity: () => context.go(activityRoute(contactId)),
        onSendDocument: () => context.push(shareRoute(contactId)),
        workspaceId: session.membership.workspaceId,
        taskAccessScope: isSalesView
            ? AssignedTaskAccess(session.user.id)
            : const WorkspaceTaskAccess(),
        taskRepository: context.read<TaskRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
      ),
    );
  }

  static Widget _contactActivityPage(
    BuildContext context, {
    required String contactId,
    required bool isSalesView,
  }) {
    final session = _authenticatedSession(context);
    return ContactActivityPage(
      workspaceId: session.membership.workspaceId,
      contactId: contactId,
      activityRepository: context.read<ActivityRepository>(),
      taskRepository: context.read<TaskRepository>(),
      taskAccessScope: isSalesView
          ? AssignedTaskAccess(session.user.id)
          : const WorkspaceTaskAccess(),
      salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
      isSalesView: isSalesView,
    );
  }

  static Widget _callNoteFormPage(
    BuildContext context, {
    required String contactId,
    required bool canAssignFollowUp,
  }) {
    final session = _authenticatedSession(context);

    return BlocProvider(
      create: (context) => CallNoteFormCubit(
        activityRepository: context.read<ActivityRepository>(),
        workspaceId: session.membership.workspaceId,
        contactId: contactId,
        actorUserId: session.user.id,
        canAssignFollowUp: canAssignFollowUp,
        fixedAssigneeId: canAssignFollowUp ? '' : session.user.id,
        salesAssigneeRepository: context.read<SalesAssigneeRepository>(),
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
