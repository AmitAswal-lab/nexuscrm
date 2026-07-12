import 'package:equatable/equatable.dart';

enum ActivityFailureCode {
  permissionDenied,
  notFound,
  invalidData,
  networkUnavailable,
  conflict,
  unknown,
}

final class ActivityFailure extends Equatable implements Exception {
  const ActivityFailure(this.code);

  final ActivityFailureCode code;

  @override
  List<Object> get props => [code];

  @override
  String toString() => 'ActivityFailure($code)';
}
