part of 'session_bloc.dart';

enum SessionAccessDeniedReason { noMembership, suspended, revoked }

enum SessionConfigurationErrorReason {
  multipleActiveMemberships,
  multipleInvitations,
}

sealed class SessionState extends Equatable {
  const SessionState();
}

final class SessionInitial extends SessionState {
  const SessionInitial();

  @override
  List<Object?> get props => [];
}

final class SessionUnauthenticated extends SessionState {
  const SessionUnauthenticated();

  @override
  List<Object?> get props => [];
}

final class SessionResolvingAccess extends SessionState {
  const SessionResolvingAccess(this.user);

  final AuthUser user;

  @override
  List<Object> get props => [user];
}

final class SessionAuthenticated extends SessionState {
  const SessionAuthenticated(this.session);

  final AuthSession session;

  @override
  List<Object> get props => [session];
}

final class SessionInvitationPending extends SessionState {
  const SessionInvitationPending({
    required this.user,
    required this.membership,
  });

  final AuthUser user;
  final WorkspaceMembership membership;

  @override
  List<Object> get props => [user, membership];
}

final class SessionAccessDenied extends SessionState {
  const SessionAccessDenied({required this.user, required this.reason});

  final AuthUser user;
  final SessionAccessDeniedReason reason;

  @override
  List<Object> get props => [user, reason];
}

final class SessionConfigurationError extends SessionState {
  const SessionConfigurationError({required this.user, required this.reason});

  final AuthUser user;
  final SessionConfigurationErrorReason reason;

  @override
  List<Object> get props => [user, reason];
}

final class SessionFailure extends SessionState {
  const SessionFailure(this.failure);

  final AuthenticationFailure failure;

  @override
  List<Object> get props => [failure];
}
