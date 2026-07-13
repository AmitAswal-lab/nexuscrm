export type InvitationErrorCode =
  | 'unauthenticated'
  | 'permission-denied'
  | 'invalid-argument'
  | 'already-exists'
  | 'failed-precondition'
  | 'internal';

export class InvitationError extends Error {
  constructor(
    readonly code: InvitationErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'InvitationError';
  }
}
