import 'package:equatable/equatable.dart';

enum DocumentFailureCode {
  permissionDenied,
  sessionExpired,
  networkUnavailable,
  notFound,
  invalidData,
  tooLarge,
  conflict,
  unknown,
}

final class DocumentFailure extends Equatable implements Exception {
  const DocumentFailure(this.code);

  final DocumentFailureCode code;

  @override
  List<Object?> get props => [code];
}
