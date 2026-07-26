import { createHash } from 'node:crypto';

import type { DocumentSnapshot, Firestore } from 'firebase-admin/firestore';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { InvitationError } from './invitation_error.js';

function hashEmail(email: string): string {
  return createHash('sha256').update(email).digest('hex');
}

export type InvitationStatus = 'pending' | 'accepted' | 'expired' | 'revoked';
export type InvitationEmailRequestStatus =
  | 'pending'
  | 'requesting'
  | 'accepted'
  | 'failed';
export type EmailRequestAttemptReservation =
  | 'reserved'
  | 'in-progress'
  | 'rate-limited';
export type InvitationAcceptance = 'accepted' | 'expired';
export type SalesRepresentativeAction = 'suspend' | 'reactivate' | 'revoke';

export interface InvitationRecord {
  readonly id: string;
  readonly workspaceId: string;
  readonly email: string;
  readonly emailHash: string;
  readonly invitedUserId: string;
  readonly expiresAt: Date;
  readonly status: InvitationStatus;
  readonly emailRequestStatus: InvitationEmailRequestStatus;
}

export interface NewInvitationRecord {
  readonly workspaceId: string;
  readonly email: string;
  readonly emailHash: string;
  readonly invitedUserId: string;
  readonly invitedByUserId: string;
  readonly createdAt: Date;
  readonly expiresAt: Date;
}

export interface InvitationStore {
  requireActiveAdmin(workspaceId: string, userId: string): Promise<void>;
  findPendingInvitation(
    workspaceId: string,
    emailHash: string,
  ): Promise<InvitationRecord | null>;
  createInvitation(record: NewInvitationRecord): Promise<InvitationRecord>;
  findInvitation(workspaceId: string, invitationId: string): Promise<InvitationRecord>;
  reserveEmailRequestAttempt(
    invitation: InvitationRecord,
    at: Date,
  ): Promise<EmailRequestAttemptReservation>;
  markEmailRequestAccepted(
    invitation: InvitationRecord,
    at: Date,
    isResend: boolean,
  ): Promise<void>;
  markEmailRequestFailed(invitation: InvitationRecord, at: Date): Promise<void>;
  markExpired(invitation: InvitationRecord, at: Date): Promise<void>;
  revokePendingInvitation({
    workspaceId,
    invitationId,
    actingUserId,
    at,
  }: {
    workspaceId: string;
    invitationId: string;
    actingUserId: string;
    at: Date;
  }): Promise<void>;
  acceptInvitation({
    workspaceId,
    invitationId,
    userId,
    displayName,
    at,
  }: {
    workspaceId: string;
    invitationId: string;
    userId: string;
    displayName: string;
    at: Date;
  }): Promise<InvitationAcceptance>;
  updateSalesRepresentativeStatus({
    workspaceId,
    actingUserId,
    userId,
    action,
    at,
  }: {
    workspaceId: string;
    actingUserId: string;
    userId: string;
    action: SalesRepresentativeAction;
    at: Date;
  }): Promise<void>;
}

export class FirestoreInvitationStore implements InvitationStore {
  constructor(private readonly firestore: Firestore) {}

  async requireActiveAdmin(workspaceId: string, userId: string): Promise<void> {
    const snapshot = await this.#member(workspaceId, userId).get();
    const data = snapshot.data();

    if (
      !snapshot.exists ||
      data?.workspaceId !== workspaceId ||
      data.userId !== userId ||
      data.role !== 'admin' ||
      data.status !== 'active'
    ) {
      throw new InvitationError(
        'permission-denied',
        'Only active administrators can create invitations.',
      );
    }
  }

  async findPendingInvitation(
    workspaceId: string,
    emailHash: string,
  ): Promise<InvitationRecord | null> {
    const lock = await this.#lock(workspaceId, emailHash).get();
    const lockData = lock.data();
    const invitationId = lockData?.invitationId;

    if (
      !lock.exists ||
      lockData?.status !== 'pending' ||
      typeof invitationId !== 'string'
    ) {
      return null;
    }

    const invitation = await this.#invitation(workspaceId, invitationId).get();
    if (!invitation.exists) {
      throw new InvitationError('internal', 'Invitation state is unavailable.');
    }

    return this.#record(workspaceId, invitation);
  }

  async findInvitation(
    workspaceId: string,
    invitationId: string,
  ): Promise<InvitationRecord> {
    const invitation = await this.#invitation(workspaceId, invitationId).get();
    if (!invitation.exists) {
      throw new InvitationError('failed-precondition', 'Invitation is unavailable.');
    }
    return this.#record(workspaceId, invitation);
  }

  async createInvitation(record: NewInvitationRecord): Promise<InvitationRecord> {
    const invitation = this.firestore
      .collection('workspaces')
      .doc(record.workspaceId)
      .collection('invitations')
      .doc();
    const member = this.#member(record.workspaceId, record.invitedUserId);
    const lock = this.#lock(record.workspaceId, record.emailHash);

    await this.firestore.runTransaction(async (transaction) => {
      const [existingLock, existingMember] = await Promise.all([
        transaction.get(lock),
        transaction.get(member),
      ]);

      if (existingLock.exists || existingMember.exists) {
        throw new InvitationError(
          'already-exists',
          'This email already has an invitation or membership in the workspace.',
        );
      }

      transaction.create(invitation, {
        workspaceId: record.workspaceId,
        email: record.email,
        emailHash: record.emailHash,
        role: 'sales_rep',
        status: 'pending',
        emailRequestStatus: 'pending',
        emailRequestAttempts: 0,
        invitedUserId: record.invitedUserId,
        invitedByUserId: record.invitedByUserId,
        createdAt: Timestamp.fromDate(record.createdAt),
        updatedAt: Timestamp.fromDate(record.createdAt),
        expiresAt: Timestamp.fromDate(record.expiresAt),
        lastEmailRequestAt: null,
        lastEmailRequestAcceptedAt: null,
        resendRequestCount: 0,
        acceptedAt: null,
        acceptedByUserId: null,
        revokedAt: null,
        revokedByUserId: null,
      });
      transaction.create(member, {
        workspaceId: record.workspaceId,
        userId: record.invitedUserId,
        email: record.email,
        role: 'sales_rep',
        status: 'invited',
        invitationId: invitation.id,
        createdAt: Timestamp.fromDate(record.createdAt),
        createdByUserId: record.invitedByUserId,
        updatedAt: Timestamp.fromDate(record.createdAt),
        updatedByUserId: record.invitedByUserId,
        statusChangedAt: Timestamp.fromDate(record.createdAt),
        statusChangedByUserId: record.invitedByUserId,
      });
      transaction.create(lock, {
        invitationId: invitation.id,
        status: 'pending',
        createdAt: Timestamp.fromDate(record.createdAt),
        updatedAt: Timestamp.fromDate(record.createdAt),
      });
    });

    return {
      id: invitation.id,
      workspaceId: record.workspaceId,
      email: record.email,
      emailHash: record.emailHash,
      invitedUserId: record.invitedUserId,
      expiresAt: record.expiresAt,
      status: 'pending',
      emailRequestStatus: 'pending',
    };
  }

  async reserveEmailRequestAttempt(
    invitation: InvitationRecord,
    at: Date,
  ): Promise<EmailRequestAttemptReservation> {
    const reference = this.#invitation(invitation.workspaceId, invitation.id);

    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const data = snapshot.data();
      if (!snapshot.exists || data?.status !== 'pending') {
        throw new InvitationError('failed-precondition', 'Invitation is unavailable.');
      }

      if (data.emailRequestStatus === 'requesting') {
        return 'in-progress';
      }

      const lastAttempt = data.lastEmailRequestAt;
      if (
        lastAttempt instanceof Timestamp &&
        at.getTime() - lastAttempt.toMillis() < 60 * 1000
      ) {
        return 'rate-limited';
      }

      transaction.update(reference, {
        emailRequestStatus: 'requesting',
        emailRequestAttempts: FieldValue.increment(1),
        lastEmailRequestAt: Timestamp.fromDate(at),
        updatedAt: Timestamp.fromDate(at),
      });
      return 'reserved';
    });
  }

  async markEmailRequestAccepted(
    invitation: InvitationRecord,
    at: Date,
    isResend: boolean,
  ): Promise<void> {
    await this.#invitation(invitation.workspaceId, invitation.id).update({
      emailRequestStatus: 'accepted',
      lastEmailRequestAcceptedAt: Timestamp.fromDate(at),
      updatedAt: Timestamp.fromDate(at),
      ...(isResend ? { resendRequestCount: FieldValue.increment(1) } : {}),
    });
  }

  async markEmailRequestFailed(
    invitation: InvitationRecord,
    at: Date,
  ): Promise<void> {
    await this.#invitation(invitation.workspaceId, invitation.id).update({
      emailRequestStatus: 'failed',
      updatedAt: Timestamp.fromDate(at),
    });
  }

  async markExpired(invitation: InvitationRecord, at: Date): Promise<void> {
    await this.firestore.runTransaction(async (transaction) => {
      transaction.update(this.#invitation(invitation.workspaceId, invitation.id), {
        status: 'expired',
        updatedAt: Timestamp.fromDate(at),
      });
      transaction.update(this.#lock(invitation.workspaceId, invitation.emailHash), {
        status: 'expired',
        updatedAt: Timestamp.fromDate(at),
      });
    });
  }

  async revokePendingInvitation({
    workspaceId,
    invitationId,
    actingUserId,
    at,
  }: {
    workspaceId: string;
    invitationId: string;
    actingUserId: string;
    at: Date;
  }): Promise<void> {
    const invitation = this.#invitation(workspaceId, invitationId);

    await this.firestore.runTransaction(async (transaction) => {
      const invitationSnapshot = await transaction.get(invitation);
      const data = invitationSnapshot.data();
      if (
        !invitationSnapshot.exists ||
        data?.workspaceId !== workspaceId ||
        data.status !== 'pending' ||
        typeof data.invitedUserId !== 'string' ||
        typeof data.emailHash !== 'string'
      ) {
        throw new InvitationError(
          'failed-precondition',
          'Only pending invitations can be revoked.',
        );
      }

      const member = this.#member(workspaceId, data.invitedUserId);
      const lock = this.#lock(workspaceId, data.emailHash);
      const [memberSnapshot, lockSnapshot] = await Promise.all([
        transaction.get(member),
        transaction.get(lock),
      ]);

      transaction.update(invitation, {
        status: 'revoked',
        revokedAt: Timestamp.fromDate(at),
        revokedByUserId: actingUserId,
        updatedAt: Timestamp.fromDate(at),
      });

      if (lockSnapshot.data()?.invitationId === invitationId) {
        transaction.update(lock, {
          status: 'revoked',
          updatedAt: Timestamp.fromDate(at),
        });
      }

      const memberData = memberSnapshot.data();
      if (
        memberSnapshot.exists &&
        memberData?.invitationId === invitationId &&
        memberData.status === 'invited'
      ) {
        transaction.update(member, {
          status: 'revoked',
          updatedAt: Timestamp.fromDate(at),
          updatedByUserId: actingUserId,
          statusChangedAt: Timestamp.fromDate(at),
          statusChangedByUserId: actingUserId,
        });
      }
    });
  }

  async acceptInvitation({
    workspaceId,
    invitationId,
    userId,
    displayName,
    at,
  }: {
    workspaceId: string;
    invitationId: string;
    userId: string;
    displayName: string;
    at: Date;
  }): Promise<InvitationAcceptance> {
    const invitation = this.#invitation(workspaceId, invitationId);
    const member = this.#member(workspaceId, userId);

    return this.firestore.runTransaction(async (transaction) => {
      const [invitationSnapshot, memberSnapshot] = await Promise.all([
        transaction.get(invitation),
        transaction.get(member),
      ]);
      const invitationData = invitationSnapshot.data();
      const memberData = memberSnapshot.data();

      if (
        !invitationSnapshot.exists ||
        invitationData?.workspaceId !== workspaceId ||
        invitationData.status !== 'pending' ||
        invitationData.invitedUserId !== userId ||
        typeof invitationData.emailHash !== 'string' ||
        !(invitationData.expiresAt instanceof Timestamp) ||
        !memberSnapshot.exists ||
        memberData?.workspaceId !== workspaceId ||
        memberData.userId !== userId ||
        memberData.role !== 'sales_rep' ||
        memberData.status !== 'invited' ||
        memberData.invitationId !== invitationId
      ) {
        throw new InvitationError(
          'failed-precondition',
          'This invitation is no longer available.',
        );
      }

      const lock = this.#lock(workspaceId, invitationData.emailHash);
      const lockSnapshot = await transaction.get(lock);
      if (
        !lockSnapshot.exists ||
        lockSnapshot.data()?.invitationId !== invitationId ||
        lockSnapshot.data()?.status !== 'pending'
      ) {
        throw new InvitationError('internal', 'Invitation state is unavailable.');
      }

      if (invitationData.expiresAt.toMillis() <= at.getTime()) {
        transaction.update(invitation, {
          status: 'expired',
          updatedAt: Timestamp.fromDate(at),
        });
        transaction.update(lock, {
          status: 'expired',
          updatedAt: Timestamp.fromDate(at),
        });
        return 'expired';
      }

      transaction.update(invitation, {
        status: 'accepted',
        acceptedAt: Timestamp.fromDate(at),
        acceptedByUserId: userId,
        updatedAt: Timestamp.fromDate(at),
      });
      transaction.update(lock, {
        status: 'accepted',
        updatedAt: Timestamp.fromDate(at),
      });
      transaction.update(member, {
        status: 'active',
        displayName,
        updatedAt: Timestamp.fromDate(at),
        updatedByUserId: userId,
        statusChangedAt: Timestamp.fromDate(at),
        statusChangedByUserId: userId,
      });
      return 'accepted';
    });
  }

  async updateSalesRepresentativeStatus({
    workspaceId,
    actingUserId,
    userId,
    action,
    at,
  }: {
    workspaceId: string;
    actingUserId: string;
    userId: string;
    action: SalesRepresentativeAction;
    at: Date;
  }): Promise<void> {
    const actor = this.#member(workspaceId, actingUserId);
    const member = this.#member(workspaceId, userId);

    await this.firestore.runTransaction(async (transaction) => {
      const [actorSnapshot, memberSnapshot] = await Promise.all([
        transaction.get(actor),
        transaction.get(member),
      ]);
      const actorData = actorSnapshot.data();
      const memberData = memberSnapshot.data();

      if (
        !actorSnapshot.exists ||
        actorData?.workspaceId !== workspaceId ||
        actorData.userId !== actingUserId ||
        actorData.role !== 'admin' ||
        actorData.status !== 'active'
      ) {
        throw new InvitationError(
          'permission-denied',
          'Only active administrators can manage representatives.',
        );
      }

      if (
        !memberSnapshot.exists ||
        memberData?.workspaceId !== workspaceId ||
        memberData.userId !== userId ||
        memberData.role !== 'sales_rep' ||
        userId === actingUserId
      ) {
        throw new InvitationError(
          'failed-precondition',
          'Only sales representatives can be managed.',
        );
      }

      let nextStatus: 'active' | 'suspended' | 'revoked';
      switch (action) {
        case 'suspend':
          if (memberData.status !== 'active') {
            throw new InvitationError(
              'failed-precondition',
              'Only active representatives can be suspended.',
            );
          }
          nextStatus = 'suspended';
          break;
        case 'reactivate':
          if (memberData.status !== 'suspended') {
            throw new InvitationError(
              'failed-precondition',
              'Only suspended representatives can be reactivated.',
            );
          }
          nextStatus = 'active';
          break;
        case 'revoke':
          if (memberData.status !== 'active' && memberData.status !== 'suspended') {
            throw new InvitationError(
              'failed-precondition',
              'Only active or suspended representatives can be revoked.',
            );
          }
          nextStatus = 'revoked';
          break;
      }

      if (nextStatus === 'revoked' && typeof memberData.email === 'string') {
        const lock = this.#lock(workspaceId, hashEmail(memberData.email));
        if ((await transaction.get(lock)).exists) {
          transaction.delete(lock);
        }
      }

      transaction.update(member, {
        status: nextStatus,
        updatedAt: Timestamp.fromDate(at),
        updatedByUserId: actingUserId,
        statusChangedAt: Timestamp.fromDate(at),
        statusChangedByUserId: actingUserId,
      });
    });
  }

  #member(workspaceId: string, userId: string) {
    return this.firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('members')
      .doc(userId);
  }

  #invitation(workspaceId: string, invitationId: string) {
    return this.firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('invitations')
      .doc(invitationId);
  }

  #lock(workspaceId: string, emailHash: string) {
    return this.firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('invitationLocks')
      .doc(emailHash);
  }

  #record(
    workspaceId: string,
    snapshot: DocumentSnapshot,
  ): InvitationRecord {
    const data = snapshot.data();
    if (
      data?.workspaceId !== workspaceId ||
      !['pending', 'accepted', 'expired', 'revoked'].includes(data.status) ||
      typeof data.email !== 'string' ||
      typeof data.emailHash !== 'string' ||
      typeof data.invitedUserId !== 'string' ||
      !(data.expiresAt instanceof Timestamp) ||
      !['pending', 'requesting', 'accepted', 'failed'].includes(
        data.emailRequestStatus,
      )
    ) {
      throw new InvitationError('internal', 'Invitation state is unavailable.');
    }

    return {
      id: snapshot.id,
      workspaceId,
      email: data.email,
      emailHash: data.emailHash,
      invitedUserId: data.invitedUserId,
      expiresAt: data.expiresAt.toDate(),
      status: data.status as InvitationStatus,
      emailRequestStatus:
        data.emailRequestStatus as InvitationEmailRequestStatus,
    };
  }
}
