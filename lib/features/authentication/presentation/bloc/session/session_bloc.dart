import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_session.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';

part 'session_event.dart';
part 'session_state.dart';

final class SessionBloc extends Bloc<SessionEvent, SessionState> {
  SessionBloc({
    required AuthenticationRepository authenticationRepository,
    required MembershipRepository membershipRepository,
  }) : this._(authenticationRepository, membershipRepository);

  SessionBloc._(this._authenticationRepository, this._membershipRepository)
    : super(const SessionInitial()) {
    on<SessionStarted>(_onStarted);
    on<SessionSignOutRequested>(_onSignOutRequested);
    on<_SessionAuthUserChanged>(_onAuthUserChanged);
    on<_SessionAuthFailureOccurred>(_onAuthFailureOccurred);
    on<_SessionMembershipsChanged>(_onMembershipsChanged);
    on<_SessionMembershipFailureOccurred>(_onMembershipFailureOccurred);
  }

  final AuthenticationRepository _authenticationRepository;
  final MembershipRepository _membershipRepository;

  StreamSubscription<AuthUser?>? _authSubscription;
  StreamSubscription<List<WorkspaceMembership>>? _membershipSubscription;
  AuthUser? _currentUser;
  int _membershipGeneration = 0;
  bool _started = false;

  void _onStarted(SessionStarted event, Emitter<SessionState> emit) {
    if (_started) {
      return;
    }

    _started = true;
    _authSubscription = _authenticationRepository.watchAuthUser().listen(
      (user) => _addIfOpen(_SessionAuthUserChanged(user)),
      onError: (Object error, StackTrace stackTrace) {
        _addIfOpen(_SessionAuthFailureOccurred(_mapFailure(error)));
      },
    );
  }

  Future<void> _onSignOutRequested(
    SessionSignOutRequested event,
    Emitter<SessionState> emit,
  ) async {
    try {
      await _authenticationRepository.signOut();
    } on Object catch (error) {
      emit(SessionFailure(_mapFailure(error)));
    }
  }

  void _onAuthUserChanged(
    _SessionAuthUserChanged event,
    Emitter<SessionState> emit,
  ) {
    _currentUser = event.user;
    _membershipGeneration++;
    final generation = _membershipGeneration;

    final previousSubscription = _membershipSubscription;
    _membershipSubscription = null;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }

    final user = event.user;
    if (user == null) {
      emit(const SessionUnauthenticated());
      return;
    }

    emit(SessionResolvingAccess(user));

    _membershipSubscription = _membershipRepository
        .watchMemberships(userId: user.id)
        .listen(
          (memberships) => _addIfOpen(
            _SessionMembershipsChanged(
              userId: user.id,
              generation: generation,
              memberships: memberships,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            _addIfOpen(
              _SessionMembershipFailureOccurred(
                userId: user.id,
                generation: generation,
                failure: _mapFailure(error),
              ),
            );
          },
        );
  }

  void _onAuthFailureOccurred(
    _SessionAuthFailureOccurred event,
    Emitter<SessionState> emit,
  ) {
    _currentUser = null;
    _membershipGeneration++;

    final previousSubscription = _membershipSubscription;
    _membershipSubscription = null;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }

    emit(SessionFailure(event.failure));
  }

  void _onMembershipsChanged(
    _SessionMembershipsChanged event,
    Emitter<SessionState> emit,
  ) {
    final user = _currentUser;
    if (user == null ||
        user.id != event.userId ||
        event.generation != _membershipGeneration) {
      return;
    }

    final activeMemberships = event.memberships
        .where((membership) => membership.status == MembershipStatus.active)
        .toList(growable: false);

    if (activeMemberships.length > 1) {
      emit(
        SessionConfigurationError(
          user: user,
          reason: SessionConfigurationErrorReason.multipleActiveMemberships,
        ),
      );
      return;
    }

    if (activeMemberships.length == 1) {
      emit(
        SessionAuthenticated(
          AuthSession(user: user, membership: activeMemberships.single),
        ),
      );
      return;
    }

    final invitedMemberships = event.memberships
        .where((membership) => membership.status == MembershipStatus.invited)
        .toList(growable: false);

    if (invitedMemberships.length > 1) {
      emit(
        SessionConfigurationError(
          user: user,
          reason: SessionConfigurationErrorReason.multipleInvitations,
        ),
      );
      return;
    }

    if (invitedMemberships.length == 1) {
      emit(
        SessionInvitationPending(
          user: user,
          membership: invitedMemberships.single,
        ),
      );
      return;
    }

    if (event.memberships.any(
      (membership) => membership.status == MembershipStatus.suspended,
    )) {
      emit(
        SessionAccessDenied(
          user: user,
          reason: SessionAccessDeniedReason.suspended,
        ),
      );
      return;
    }

    if (event.memberships.any(
      (membership) => membership.status == MembershipStatus.revoked,
    )) {
      emit(
        SessionAccessDenied(
          user: user,
          reason: SessionAccessDeniedReason.revoked,
        ),
      );
      return;
    }

    emit(
      SessionAccessDenied(
        user: user,
        reason: SessionAccessDeniedReason.noMembership,
      ),
    );
  }

  void _onMembershipFailureOccurred(
    _SessionMembershipFailureOccurred event,
    Emitter<SessionState> emit,
  ) {
    final user = _currentUser;
    if (user == null ||
        user.id != event.userId ||
        event.generation != _membershipGeneration) {
      return;
    }

    emit(SessionFailure(event.failure));
  }

  void _addIfOpen(SessionEvent event) {
    if (!isClosed) {
      add(event);
    }
  }

  static AuthenticationFailure _mapFailure(Object error) {
    return error is AuthenticationFailure
        ? error
        : const AuthenticationFailure(AuthenticationFailureCode.unknown);
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    await _membershipSubscription?.cancel();
    return super.close();
  }
}
