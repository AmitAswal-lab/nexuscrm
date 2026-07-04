part of 'session_bloc.dart';

sealed class SessionEvent extends Equatable {
  const SessionEvent();
}

final class SessionStarted extends SessionEvent {
  const SessionStarted();

  @override
  List<Object?> get props => [];
}

final class SessionSignOutRequested extends SessionEvent {
  const SessionSignOutRequested();

  @override
  List<Object?> get props => [];
}

final class _SessionAuthUserChanged extends SessionEvent {
  const _SessionAuthUserChanged(this.user);

  final AuthUser? user;

  @override
  List<Object?> get props => [user];
}

final class _SessionAuthFailureOccurred extends SessionEvent {
  const _SessionAuthFailureOccurred(this.failure);

  final AuthenticationFailure failure;

  @override
  List<Object> get props => [failure];
}

final class _SessionMembershipsChanged extends SessionEvent {
  const _SessionMembershipsChanged({
    required this.userId,
    required this.generation,
    required this.memberships,
  });

  final String userId;
  final int generation;
  final List<WorkspaceMembership> memberships;

  @override
  List<Object> get props => [userId, generation, memberships];
}

final class _SessionMembershipFailureOccurred extends SessionEvent {
  const _SessionMembershipFailureOccurred({
    required this.userId,
    required this.generation,
    required this.failure,
  });

  final String userId;
  final int generation;
  final AuthenticationFailure failure;

  @override
  List<Object> get props => [userId, generation, failure];
}
