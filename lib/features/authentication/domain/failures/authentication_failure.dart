import 'package:equatable/equatable.dart';

enum AuthenticationFailureCode {
  invalidCredentials,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  networkUnavailable,
  operationNotAllowed,
  unknown,
}

final class AuthenticationFailure extends Equatable implements Exception {
  const AuthenticationFailure(this.code);

  final AuthenticationFailureCode code;

  @override
  List<Object> get props => [code];
}
