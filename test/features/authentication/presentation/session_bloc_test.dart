import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_session.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';
import 'package:nexuscrm/features/authentication/presentation/bloc/session/session_bloc.dart';

const _adminUser = AuthUser(id: 'admin-user', email: 'admin@example.com');
const _salesUser = AuthUser(id: 'sales-user', email: 'sales@example.com');

void main() {
  late _ControllableAuthenticationRepository authenticationRepository;
  late _ControllableMembershipRepository membershipRepository;

  setUp(() {
    authenticationRepository = _ControllableAuthenticationRepository();
    membershipRepository = _ControllableMembershipRepository();
  });

  tearDown(() async {
    await authenticationRepository.close();
    await membershipRepository.close();
  });

  SessionBloc buildBloc() => SessionBloc(
    authenticationRepository: authenticationRepository,
    membershipRepository: membershipRepository,
  );

  blocTest<SessionBloc, SessionState>(
    'restores a signed-out session',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(null);
    },
    expect: () => const <SessionState>[SessionUnauthenticated()],
  );

  blocTest<SessionBloc, SessionState>(
    'resolves one active membership into an authenticated session',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      membershipRepository.emit(_adminUser.id, <WorkspaceMembership>[
        _membership(),
      ]);
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionAuthenticated(
        AuthSession(user: _adminUser, membership: _activeAdminMembership),
      ),
    ],
  );

  for (final testCase in <(MembershipStatus, SessionState)>[
    (
      MembershipStatus.invited,
      const SessionInvitationPending(
        user: _adminUser,
        membership: WorkspaceMembership(
          workspaceId: 'workspace-one',
          userId: 'admin-user',
          role: WorkspaceRole.admin,
          status: MembershipStatus.invited,
        ),
      ),
    ),
    (
      MembershipStatus.suspended,
      const SessionAccessDenied(
        user: _adminUser,
        reason: SessionAccessDeniedReason.suspended,
      ),
    ),
    (
      MembershipStatus.revoked,
      const SessionAccessDenied(
        user: _adminUser,
        reason: SessionAccessDeniedReason.revoked,
      ),
    ),
  ]) {
    blocTest<SessionBloc, SessionState>(
      'maps ${testCase.$1.name} membership access',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const SessionStarted());
        await _nextEventLoop();
        authenticationRepository.emit(_adminUser);
        await _nextEventLoop();
        membershipRepository.emit(_adminUser.id, <WorkspaceMembership>[
          _membership(status: testCase.$1),
        ]);
      },
      expect: () => <SessionState>[
        const SessionResolvingAccess(_adminUser),
        testCase.$2,
      ],
    );
  }

  blocTest<SessionBloc, SessionState>(
    'denies access when no membership exists',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      membershipRepository.emit(_adminUser.id, const <WorkspaceMembership>[]);
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionAccessDenied(
        user: _adminUser,
        reason: SessionAccessDeniedReason.noMembership,
      ),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'treats multiple active memberships as a configuration error',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      membershipRepository.emit(_adminUser.id, <WorkspaceMembership>[
        _membership(),
        _membership(workspaceId: 'workspace-two'),
      ]);
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionConfigurationError(
        user: _adminUser,
        reason: SessionConfigurationErrorReason.multipleActiveMemberships,
      ),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'treats multiple invitations as a configuration error',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      membershipRepository.emit(_adminUser.id, <WorkspaceMembership>[
        _membership(status: MembershipStatus.invited),
        _membership(
          workspaceId: 'workspace-two',
          status: MembershipStatus.invited,
        ),
      ]);
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionConfigurationError(
        user: _adminUser,
        reason: SessionConfigurationErrorReason.multipleInvitations,
      ),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'ignores stale memberships after the authenticated user changes',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      authenticationRepository.emit(_salesUser);
      await _nextEventLoop();
      membershipRepository.emit(_adminUser.id, <WorkspaceMembership>[
        _membership(),
      ]);
      membershipRepository.emit(_salesUser.id, <WorkspaceMembership>[
        _membership(userId: _salesUser.id, role: WorkspaceRole.salesRep),
      ]);
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionResolvingAccess(_salesUser),
      SessionAuthenticated(
        AuthSession(
          user: _salesUser,
          membership: WorkspaceMembership(
            workspaceId: 'workspace-one',
            userId: 'sales-user',
            role: WorkspaceRole.salesRep,
            status: MembershipStatus.active,
          ),
        ),
      ),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'maps authentication and membership stream errors',
    build: buildBloc,
    act: (bloc) async {
      bloc.add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();
      membershipRepository.emitError(
        _adminUser.id,
        const AuthenticationFailure(AuthenticationFailureCode.permissionDenied),
      );
    },
    expect: () => const <SessionState>[
      SessionResolvingAccess(_adminUser),
      SessionFailure(
        AuthenticationFailure(AuthenticationFailureCode.permissionDenied),
      ),
    ],
  );

  blocTest<SessionBloc, SessionState>(
    'delegates sign-out and exposes sign-out failures',
    setUp: () {
      authenticationRepository.signOutFailure = const AuthenticationFailure(
        AuthenticationFailureCode.networkUnavailable,
      );
    },
    build: buildBloc,
    act: (bloc) => bloc.add(const SessionSignOutRequested()),
    expect: () => const <SessionState>[
      SessionFailure(
        AuthenticationFailure(AuthenticationFailureCode.networkUnavailable),
      ),
    ],
    verify: (_) {
      expect(authenticationRepository.signOutCalls, 1);
    },
  );

  test(
    'cancels authentication and membership subscriptions on close',
    () async {
      final bloc = buildBloc()..add(const SessionStarted());
      await _nextEventLoop();
      authenticationRepository.emit(_adminUser);
      await _nextEventLoop();

      expect(authenticationRepository.hasListener, isTrue);
      expect(membershipRepository.hasListener(_adminUser.id), isTrue);

      await bloc.close();

      expect(authenticationRepository.hasListener, isFalse);
      expect(membershipRepository.hasListener(_adminUser.id), isFalse);
    },
  );
}

const _activeAdminMembership = WorkspaceMembership(
  workspaceId: 'workspace-one',
  userId: 'admin-user',
  role: WorkspaceRole.admin,
  status: MembershipStatus.active,
);

WorkspaceMembership _membership({
  String workspaceId = 'workspace-one',
  String userId = 'admin-user',
  WorkspaceRole role = WorkspaceRole.admin,
  MembershipStatus status = MembershipStatus.active,
}) {
  return WorkspaceMembership(
    workspaceId: workspaceId,
    userId: userId,
    role: role,
    status: status,
  );
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

final class _ControllableAuthenticationRepository
    implements AuthenticationRepository {
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast(sync: true);

  Object? signOutFailure;
  int signOutCalls = 0;

  bool get hasListener => _controller.hasListener;

  void emit(AuthUser? user) => _controller.add(user);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final failure = signOutFailure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Stream<AuthUser?> watchAuthUser() => _controller.stream;

  Future<void> close() => _controller.close();
}

final class _ControllableMembershipRepository implements MembershipRepository {
  final Map<String, StreamController<List<WorkspaceMembership>>> _controllers =
      <String, StreamController<List<WorkspaceMembership>>>{};

  StreamController<List<WorkspaceMembership>> _controller(String userId) {
    return _controllers.putIfAbsent(
      userId,
      () => StreamController<List<WorkspaceMembership>>.broadcast(sync: true),
    );
  }

  void emit(String userId, List<WorkspaceMembership> memberships) {
    _controller(userId).add(memberships);
  }

  void emitError(String userId, Object error) {
    _controller(userId).addError(error);
  }

  bool hasListener(String userId) => _controller(userId).hasListener;

  @override
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId}) {
    return _controller(userId).stream;
  }

  Future<void> close() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}
