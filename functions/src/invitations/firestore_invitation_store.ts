import type { DocumentSnapshot, Firestore } from 'firebase-admin/firestore';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { InvitationError } from './invitation_error.js';

export type InvitationDeliveryStatus = 'pending' | 'sending' | 'sent' | 'failed';

export interface InvitationRecord {
  readonly id: string;
  readonly workspaceId: string;
  readonly email: string;
  readonly emailHash: string;
  readonly invitedUserId: string;
  readonly expiresAt: Date;
  readonly status: 'pending';
  readonly deliveryStatus: InvitationDeliveryStatus;
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
  markDeliveryAttempt(invitation: InvitationRecord, at: Date): Promise<boolean>;
  markDeliverySent(invitation: InvitationRecord, at: Date): Promise<void>;
  markDeliveryFailed(invitation: InvitationRecord, at: Date): Promise<void>;
  markExpired(invitation: InvitationRecord, at: Date): Promise<void>;
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
        deliveryStatus: 'pending',
        deliveryAttempts: 0,
        invitedUserId: record.invitedUserId,
        invitedByUserId: record.invitedByUserId,
        createdAt: Timestamp.fromDate(record.createdAt),
        updatedAt: Timestamp.fromDate(record.createdAt),
        expiresAt: Timestamp.fromDate(record.expiresAt),
        lastSentAt: null,
        resendCount: 0,
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
      deliveryStatus: 'pending',
    };
  }

  async markDeliveryAttempt(
    invitation: InvitationRecord,
    at: Date,
  ): Promise<boolean> {
    const reference = this.#invitation(invitation.workspaceId, invitation.id);

    return this.firestore.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(reference);
      const deliveryStatus = snapshot.data()?.deliveryStatus;
      if (deliveryStatus !== 'pending' && deliveryStatus !== 'failed') {
        return false;
      }

      transaction.update(reference, {
        deliveryStatus: 'sending',
        deliveryAttempts: FieldValue.increment(1),
        updatedAt: Timestamp.fromDate(at),
      });
      return true;
    });
  }

  async markDeliverySent(invitation: InvitationRecord, at: Date): Promise<void> {
    await this.#invitation(invitation.workspaceId, invitation.id).update({
      deliveryStatus: 'sent',
      lastSentAt: Timestamp.fromDate(at),
      updatedAt: Timestamp.fromDate(at),
    });
  }

  async markDeliveryFailed(invitation: InvitationRecord, at: Date): Promise<void> {
    await this.#invitation(invitation.workspaceId, invitation.id).update({
      deliveryStatus: 'failed',
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
      data.status !== 'pending' ||
      typeof data.email !== 'string' ||
      typeof data.emailHash !== 'string' ||
      typeof data.invitedUserId !== 'string' ||
      !(data.expiresAt instanceof Timestamp) ||
      !['pending', 'sending', 'sent', 'failed'].includes(data.deliveryStatus)
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
      status: 'pending',
      deliveryStatus: data.deliveryStatus as InvitationDeliveryStatus,
    };
  }
}
