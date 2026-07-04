import 'package:equatable/equatable.dart';

enum ContactFailureCode {
  permissionDenied,
  notFound,
  invalidData,
  networkUnavailable,
  conflict,
  unknown,
}

final class ContactFailure extends Equatable implements Exception {
  const ContactFailure(this.code);

  final ContactFailureCode code;

  @override
  List<Object> get props => [code];

  @override
  String toString() => 'ContactFailure($code)';
}
