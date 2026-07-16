enum InvitationActionFailureCode {
  invalidInput,
  duplicate,
  accessDenied,
  rateLimited,
  expired,
  unavailable,
  unknown,
}

final class InvitationActionFailure implements Exception {
  const InvitationActionFailure(this.code);

  final InvitationActionFailureCode code;
}
