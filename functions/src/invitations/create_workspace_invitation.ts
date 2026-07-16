import { randomBytes, createHash } from 'node:crypto';

import type { Auth } from 'firebase-admin/auth';

import type { InvitationEmailSender } from '../email/invitation_email_sender.js';
import {
  type InvitationEmailRequestStatus,
  type InvitationRecord,
  type InvitationStore,
} from './firestore_invitation_store.js';
import { InvitationError } from './invitation_error.js';

const invitationLifetimeMs = 7 * 24 * 60 * 60 * 1000;

export interface CreateWorkspaceInvitationInput {
  readonly actingUserId: string;
  readonly workspaceId: string;
  readonly email: string;
}

export interface CreateWorkspaceInvitationResult {
  readonly invitationId: string;
  readonly email: string;
  readonly status: 'pending';
  readonly expiresAtMillis: number;
  readonly emailRequestStatus: 'accepted' | 'failed';
}

export class CreateWorkspaceInvitationService {
  constructor({
    auth,
    invitationStore,
    emailSender,
    now = () => new Date(),
  }: {
    auth: Auth;
    invitationStore: InvitationStore;
    emailSender: InvitationEmailSender;
    now?: () => Date;
  }) {
    this.#auth = auth;
    this.#store = invitationStore;
    this.#emailSender = emailSender;
    this.#now = now;
  }

  readonly #auth: Auth;
  readonly #store: InvitationStore;
  readonly #emailSender: InvitationEmailSender;
  readonly #now: () => Date;

  async create(
    input: CreateWorkspaceInvitationInput,
  ): Promise<CreateWorkspaceInvitationResult> {
    const workspaceId = requiredWorkspaceId(input.workspaceId);
    const email = normalizeEmail(input.email);
    const emailHash = hashEmail(email);
    const actingUserId = requiredUserId(input.actingUserId);

    await this.#store.requireActiveAdmin(workspaceId, actingUserId);

    const existingInvitation = await this.#store.findPendingInvitation(
      workspaceId,
      emailHash,
    );

    if (existingInvitation !== null) {
      if (existingInvitation.expiresAt.getTime() <= this.#now().getTime()) {
        await this.#store.markExpired(existingInvitation, this.#now());
        throw new InvitationError(
          'failed-precondition',
          'The existing invitation has expired and must be replaced by a future invitation workflow.',
        );
      }

      if (existingInvitation.emailRequestStatus === 'failed') {
        return this.#requestEmail(existingInvitation, false);
      }

      throw new InvitationError(
        'already-exists',
        'This email already has a pending invitation in the workspace.',
      );
    }

    await this.#rejectExistingAuthUser(email);
    const user = await this.#createAuthUser(email);
    const createdAt = this.#now();
    const expiresAt = new Date(createdAt.getTime() + invitationLifetimeMs);

    let invitation: InvitationRecord;
    try {
      invitation = await this.#store.createInvitation({
        workspaceId,
        email,
        emailHash,
        invitedUserId: user.uid,
        invitedByUserId: actingUserId,
        createdAt,
        expiresAt,
      });
    } catch (error) {
      await this.#deleteAuthUserAfterRecordFailure(user.uid);
      throw error;
    }

    return this.#requestEmail(invitation, false);
  }

  async resend({
    actingUserId,
    workspaceId: rawWorkspaceId,
    invitationId,
  }: {
    actingUserId: string;
    workspaceId: string;
    invitationId: string;
  }): Promise<CreateWorkspaceInvitationResult> {
    const workspaceId = requiredWorkspaceId(rawWorkspaceId);
    const userId = requiredUserId(actingUserId);
    const id = requiredInvitationId(invitationId);

    await this.#store.requireActiveAdmin(workspaceId, userId);
    const invitation = await this.#store.findInvitation(workspaceId, id);
    if (invitation.status !== 'pending') {
      throw new InvitationError(
        'failed-precondition',
        'Only pending invitations can be resent.',
      );
    }
    if (invitation.expiresAt.getTime() <= this.#now().getTime()) {
      await this.#store.markExpired(invitation, this.#now());
      throw new InvitationError('failed-precondition', 'This invitation has expired.');
    }

    return this.#requestEmail(invitation, true);
  }

  async revoke({
    actingUserId,
    workspaceId: rawWorkspaceId,
    invitationId,
  }: {
    actingUserId: string;
    workspaceId: string;
    invitationId: string;
  }): Promise<void> {
    const workspaceId = requiredWorkspaceId(rawWorkspaceId);
    const userId = requiredUserId(actingUserId);
    const id = requiredInvitationId(invitationId);

    await this.#store.requireActiveAdmin(workspaceId, userId);
    await this.#store.revokePendingInvitation({
      workspaceId,
      invitationId: id,
      actingUserId: userId,
      at: this.#now(),
    });
  }

  async #requestEmail(
    invitation: InvitationRecord,
    isResend: boolean,
  ): Promise<CreateWorkspaceInvitationResult> {
    const attemptedAt = this.#now();
    const emailRequestAttempt = await this.#store.reserveEmailRequestAttempt(
      invitation,
      attemptedAt,
    );
    if (emailRequestAttempt === 'in-progress') {
      throw new InvitationError(
        'already-exists',
        'This invitation email request is already in progress.',
      );
    }
    if (emailRequestAttempt === 'rate-limited') {
      throw new InvitationError(
        'resource-exhausted',
        'Please wait before sending another invitation email.',
      );
    }

    try {
      await this.#emailSender.requestPasswordSetup(invitation.email);
      await this.#store.markEmailRequestAccepted(
        invitation,
        this.#now(),
        isResend,
      );
      return resultFor(invitation, 'accepted');
    } catch (_) {
      await this.#store.markEmailRequestFailed(invitation, this.#now());
      return resultFor(invitation, 'failed');
    }
  }

  async #rejectExistingAuthUser(email: string): Promise<void> {
    try {
      await this.#auth.getUserByEmail(email);
    } catch (error) {
      if (hasAuthCode(error, 'auth/user-not-found')) return;
      throw new InvitationError('internal', 'Unable to validate the invitation.');
    }

    throw new InvitationError(
      'already-exists',
      'This email already belongs to a Nexus CRM account.',
    );
  }

  async #createAuthUser(email: string) {
    try {
      return await this.#auth.createUser({
        email,
        password: randomBytes(48).toString('base64url'),
        emailVerified: false,
        disabled: false,
      });
    } catch (error) {
      if (hasAuthCode(error, 'auth/email-already-exists')) {
        throw new InvitationError(
          'already-exists',
          'This email already belongs to a Nexus CRM account.',
        );
      }
      throw new InvitationError('internal', 'Unable to create the invitation.');
    }
  }

  async #deleteAuthUserAfterRecordFailure(userId: string): Promise<void> {
    try {
      await this.#auth.deleteUser(userId);
    } catch (error) {
      if (!hasAuthCode(error, 'auth/user-not-found')) {
        throw new InvitationError(
          'internal',
          'Invitation setup could not be completed safely.',
        );
      }
    }
  }
}

export function normalizeEmail(value: string): string {
  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new InvitationError('invalid-argument', 'Enter a valid email address.');
  }
  return email;
}

function requiredWorkspaceId(value: string): string {
  const workspaceId = value.trim();
  if (workspaceId.length === 0 || workspaceId.includes('/')) {
    throw new InvitationError('invalid-argument', 'Invalid workspace.');
  }
  return workspaceId;
}

function requiredUserId(value: string): string {
  const userId = value.trim();
  if (userId.length === 0) {
    throw new InvitationError('unauthenticated', 'Sign in to continue.');
  }
  return userId;
}

function requiredInvitationId(value: string): string {
  const invitationId = value.trim();
  if (invitationId.length === 0 || invitationId.includes('/')) {
    throw new InvitationError('invalid-argument', 'Invalid invitation.');
  }
  return invitationId;
}

function hashEmail(email: string): string {
  return createHash('sha256').update(email).digest('hex');
}

function resultFor(
  invitation: InvitationRecord,
  emailRequestStatus: Extract<InvitationEmailRequestStatus, 'accepted' | 'failed'>,
): CreateWorkspaceInvitationResult {
  return {
    invitationId: invitation.id,
    email: invitation.email,
    status: 'pending',
    expiresAtMillis: invitation.expiresAt.getTime(),
    emailRequestStatus,
  };
}

function hasAuthCode(error: unknown, code: string): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    error.code === code
  );
}
