import 'package:equatable/equatable.dart';

enum TaskFailureCode {
  permissionDenied,
  notFound,
  invalidData,
  networkUnavailable,
  conflict,
  unknown,
}

final class TaskFailure extends Equatable implements Exception {
  const TaskFailure(this.code);

  final TaskFailureCode code;

  @override
  List<Object> get props => [code];

  @override
  String toString() => 'TaskFailure($code)';
}
