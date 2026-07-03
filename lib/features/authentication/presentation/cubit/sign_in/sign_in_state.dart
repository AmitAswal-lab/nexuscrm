part of 'sign_in_cubit.dart';

enum SignInStatus { initial, submitting, success, failure }

final class SignInState extends Equatable {
  const SignInState({this.status = SignInStatus.initial, this.failure});

  final SignInStatus status;
  final AuthenticationFailure? failure;

  @override
  List<Object?> get props => [status, failure];
}
