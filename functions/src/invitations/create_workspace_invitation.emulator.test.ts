import assert from 'node:assert/strict';
import test, { afterEach, before } from 'node:test';

import { getAuth } from 'firebase-admin/auth';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import type { InvitationEmailSender } from '../email/invitation_email_sender.js';
import {
  CreateWorkspaceInvitationService,
} from './create_workspace_invitation.js';
import {
  FirestoreInvitationStore,
  type InvitationRecord,
  type InvitationStore,
} from './firestore_invitation_store.js';
import { InvitationError } from './invitation_error.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-nexuscrm';
const workspaceId = 'workspace-one';
const adminUserId = 'admin-user';
const now = new Date('2026-07-13T12:00:00.000Z');

if (getApps().length === 0) initializeApp({ projectId });

const firestore = getFirestore();
const auth = getAuth();

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
});

afterEach(async () => {
  await clearFirestore();
  await clearAuth();
});

test('creates only a sales invitation, invited membership, and safe response', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const sender = new RecordingSender();
  const service = makeService(sender);

  const result = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: '  Sales.Rep@Example.com ',
  });

  assert.deepEqual(result, {
    invitationId: result.invitationId,
    email: 'sales.rep@example.com',
    status: 'pending',
    expiresAtMillis: now.getTime() + 7 * 24 * 60 * 60 * 1000,
    emailRequestStatus: 'accepted',
  });
  assert.equal('userId' in result, false);
  assert.equal('emailRequestStatus' in result, true);
  assert.equal(sender.messages.length, 1);

  const invitation = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('invitations')
    .doc(result.invitationId)
    .get();
  const invitationData = invitation.data();
  assert.equal(invitationData?.role, 'sales_rep');
  assert.equal(invitationData?.status, 'pending');
  assert.equal(invitationData?.emailRequestStatus, 'accepted');
  assert.equal(invitationData?.invitedByUserId, adminUserId);
  assert.equal(invitationData?.emailRequestAttempts, 1);

  const membership = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc(String(invitationData?.invitedUserId))
    .get();
  assert.deepEqual(
    pick(membership.data(), ['role', 'status', 'invitationId', 'email']),
    {
      role: 'sales_rep',
      status: 'invited',
      invitationId: result.invitationId,
      email: 'sales.rep@example.com',
    },
  );
  assert.equal(
    (await auth.getUser(String(invitationData?.invitedUserId))).email,
    'sales.rep@example.com',
  );
});

test('rejects a non-admin without creating an Auth user', async () => {
  await seedMembership('sales-user', 'sales_rep', 'active');
  const service = makeService(new RecordingSender());

  await assert.rejects(
    service.create({
      actingUserId: 'sales-user',
      workspaceId,
      email: 'blocked@example.com',
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'permission-denied',
  );

  await assertUserMissing('blocked@example.com');
});

test('rejects a suspended or cross-workspace administrator', async () => {
  await seedMembership('suspended-admin', 'admin', 'suspended');
  await firestore
      .collection('workspaces')
      .doc('another-workspace')
      .collection('members')
      .doc('other-admin')
      .set({
        workspaceId: 'another-workspace',
        userId: 'other-admin',
        role: 'admin',
        status: 'active',
      });
  const service = makeService(new RecordingSender());

  for (const testCase of [
    ['suspended-admin', 'suspended@example.com'],
    ['other-admin', 'isolated@example.com'],
  ] as const) {
    await assert.rejects(
      service.create({
        actingUserId: testCase[0],
        workspaceId,
        email: testCase[1],
      }),
      (error: unknown) =>
        error instanceof InvitationError && error.code === 'permission-denied',
    );
    await assertUserMissing(testCase[1]);
  }
});

test('rejects an email that already has a Firebase Authentication account', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  await auth.createUser({ uid: 'existing-user', email: 'existing@example.com' });
  const service = makeService(new RecordingSender());

  await assert.rejects(
    service.create({
      actingUserId: adminUserId,
      workspaceId,
      email: 'existing@example.com',
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'already-exists',
  );
  const invitations = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('invitations')
    .get();
  assert.equal(invitations.empty, true);
});

test('retains one invitation and Auth user while retrying a failed email request', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const sender = new RecordingSender({ shouldFail: true });
  let currentTime = now;
  const service = makeService(
    sender,
    () => currentTime,
  );

  const first = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'retry@example.com',
  });
  assert.equal(first.emailRequestStatus, 'failed');

  const firstInvitation = await onlyInvitation();
  const firstUserId = String(firstInvitation.data()?.invitedUserId);
  sender.shouldFail = false;
  currentTime = new Date(now.getTime() + 61 * 1000);

  const second = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'retry@example.com',
  });

  assert.equal(second.emailRequestStatus, 'accepted');
  assert.equal(second.invitationId, first.invitationId);
  assert.equal((await onlyInvitation()).data()?.emailRequestAttempts, 2);
  assert.equal((await onlyInvitation()).data()?.emailRequestStatus, 'accepted');
  assert.equal(
    String((await onlyInvitation()).data()?.invitedUserId),
    firstUserId,
  );
  assert.equal((await auth.getUser(firstUserId)).email, 'retry@example.com');
});

test('does not duplicate a pending invitation with an accepted email request', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const sender = new RecordingSender();
  const service = makeService(sender);

  await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'pending@example.com',
  });

  await assert.rejects(
    service.create({
      actingUserId: adminUserId,
      workspaceId,
      email: 'pending@example.com',
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'already-exists',
  );
  assert.equal((await onlyInvitation()).id.length > 0, true);
  assert.equal(sender.messages.length, 1);
});

test('rate-limits a resend and records a successful resend once', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  let currentTime = now;
  const sender = new RecordingSender();
  const service = makeService(
    sender,
    () => currentTime,
  );
  const invitation = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'resend@example.com',
  });

  await assert.rejects(
    service.resend({
      actingUserId: adminUserId,
      workspaceId,
      invitationId: invitation.invitationId,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'resource-exhausted',
  );

  currentTime = new Date(now.getTime() + 61 * 1000);
  const resent = await service.resend({
    actingUserId: adminUserId,
    workspaceId,
    invitationId: invitation.invitationId,
  });

  assert.equal(resent.emailRequestStatus, 'accepted');
  assert.equal((await onlyInvitation()).data()?.resendRequestCount, 1);
  assert.equal((await onlyInvitation()).data()?.emailRequestAttempts, 2);
  assert.equal(sender.messages.length, 2);
});

test('revocation updates only the invited membership linked to the invitation', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'revoke@example.com',
  });
  const invitation = await onlyInvitation();
  const invitedUserId = String(invitation.data()?.invitedUserId);

  await service.revoke({
    actingUserId: adminUserId,
    workspaceId,
    invitationId: created.invitationId,
  });

  assert.equal((await onlyInvitation()).data()?.status, 'revoked');
  assert.equal(
    (
      await firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(invitedUserId)
        .get()
    ).data()?.status,
    'revoked',
  );
});

test('revocation never changes a linked membership once it is active', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'active@example.com',
  });
  const invitation = await onlyInvitation();
  const userId = String(invitation.data()?.invitedUserId);
  await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc(userId)
    .update({status: 'active'});

  await service.revoke({
    actingUserId: adminUserId,
    workspaceId,
    invitationId: created.invitationId,
  });

  assert.equal(
    (
      await firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(userId)
        .get()
    ).data()?.status,
    'active',
  );
});

test('accepts only the matching invited representative atomically', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'accept@example.com',
  });
  const invitation = await onlyInvitation();
  const invitedUserId = String(invitation.data()?.invitedUserId);
  const store = new FirestoreInvitationStore(firestore);

  await assert.rejects(
    store.acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: 'another-user',
      displayName: 'Sales Rep',
      at: now,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'failed-precondition',
  );

  assert.equal(
    await store.acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: invitedUserId,
      displayName: 'Sales Rep',
      at: now,
    }),
    'accepted',
  );
  assert.equal((await onlyInvitation()).data()?.status, 'accepted');
  assert.equal((await onlyInvitation()).data()?.acceptedByUserId, invitedUserId);

  const member = (
    await firestore
      .collection('workspaces')
      .doc(workspaceId)
      .collection('members')
      .doc(invitedUserId)
      .get()
  ).data();
  assert.equal(member?.status, 'active');
  assert.equal(member?.displayName, 'Sales Rep');
});

test('marks an expired invitation without activating its membership', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'expired@example.com',
  });
  const invitation = await onlyInvitation();
  const invitedUserId = String(invitation.data()?.invitedUserId);

  assert.equal(
    await new FirestoreInvitationStore(firestore).acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: invitedUserId,
      displayName: 'Sales Rep',
      at: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
    }),
    'expired',
  );
  assert.equal((await onlyInvitation()).data()?.status, 'expired');
  assert.equal(
    (
      await firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc(invitedUserId)
        .get()
    ).data()?.status,
    'invited',
  );
});

test('accepts an invitation only once and leaves the activated membership intact', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'replay@example.com',
  });
  const invitedUserId = String((await onlyInvitation()).data()?.invitedUserId);
  const store = new FirestoreInvitationStore(firestore);

  assert.equal(
    await store.acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: invitedUserId,
      displayName: 'Sales Rep',
      at: now,
    }),
    'accepted',
  );

  await assert.rejects(
    store.acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: invitedUserId,
      displayName: 'Sales Rep',
      at: new Date(now.getTime() + 1000),
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'failed-precondition',
  );

  const invitation = (await onlyInvitation()).data();
  assert.equal(invitation?.status, 'accepted');
  assert.equal(invitation?.acceptedAt.toMillis(), now.getTime());
  assert.equal(await memberStatus(invitedUserId), 'active');
});

test('refuses to activate a revoked invitation', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'revoked-accept@example.com',
  });
  const invitedUserId = String((await onlyInvitation()).data()?.invitedUserId);
  await service.revoke({
    actingUserId: adminUserId,
    workspaceId,
    invitationId: created.invitationId,
  });

  await assert.rejects(
    new FirestoreInvitationStore(firestore).acceptInvitation({
      workspaceId,
      invitationId: created.invitationId,
      userId: invitedUserId,
      displayName: 'Sales Rep',
      at: now,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'failed-precondition',
  );

  assert.equal((await onlyInvitation()).data()?.status, 'revoked');
  assert.equal(await memberStatus(invitedUserId), 'revoked');
});

test('allows an active admin to suspend, reactivate, and revoke a sales representative', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  await seedMembership('sales-user', 'sales_rep', 'active');
  const store = new FirestoreInvitationStore(firestore);

  for (const [action, expected] of [
    ['suspend', 'suspended'],
    ['reactivate', 'active'],
    ['revoke', 'revoked'],
  ] as const) {
    await store.updateSalesRepresentativeStatus({
      workspaceId,
      actingUserId: adminUserId,
      userId: 'sales-user',
      action,
      at: now,
    });
    const data = (
      await firestore
        .collection('workspaces')
        .doc(workspaceId)
        .collection('members')
        .doc('sales-user')
        .get()
    ).data();
    assert.equal(data?.status, expected);
    assert.equal(data?.statusChangedByUserId, adminUserId);
  }
});

test('refuses membership management by non-admins or against administrators', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  await seedMembership('sales-user', 'sales_rep', 'active');
  const store = new FirestoreInvitationStore(firestore);

  await assert.rejects(
    store.updateSalesRepresentativeStatus({
      workspaceId,
      actingUserId: 'sales-user',
      userId: 'sales-user',
      action: 'suspend',
      at: now,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'permission-denied',
  );
  await assert.rejects(
    store.updateSalesRepresentativeStatus({
      workspaceId,
      actingUserId: adminUserId,
      userId: adminUserId,
      action: 'suspend',
      at: now,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'failed-precondition',
  );
});

test('refuses status changes that skip the membership lifecycle', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  await seedMembership('sales-user', 'sales_rep', 'active');
  const store = new FirestoreInvitationStore(firestore);

  await assert.rejects(
    store.updateSalesRepresentativeStatus({
      workspaceId,
      actingUserId: adminUserId,
      userId: 'sales-user',
      action: 'reactivate',
      at: now,
    }),
    (error: unknown) =>
      error instanceof InvitationError && error.code === 'failed-precondition',
  );
  assert.equal(await memberStatus('sales-user'), 'active');

  await store.updateSalesRepresentativeStatus({
    workspaceId,
    actingUserId: adminUserId,
    userId: 'sales-user',
    action: 'revoke',
    at: now,
  });

  for (const action of ['suspend', 'reactivate', 'revoke'] as const) {
    await assert.rejects(
      store.updateSalesRepresentativeStatus({
        workspaceId,
        actingUserId: adminUserId,
        userId: 'sales-user',
        action,
        at: now,
      }),
      (error: unknown) =>
        error instanceof InvitationError && error.code === 'failed-precondition',
    );
  }
  assert.equal(await memberStatus('sales-user'), 'revoked');
});

test('releasing work unassigns contacts and moves only open tasks', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  await seedMembership('sales-user', 'sales_rep', 'active');
  const workspace = firestore.collection('workspaces').doc(workspaceId);
  await workspace.collection('contacts').doc('contact-one').set({
    workspaceId,
    ownerId: 'sales-user',
    fullName: 'Owned Lead',
  });
  await workspace.collection('contacts').doc('contact-two').set({
    workspaceId,
    ownerId: 'another-user',
    fullName: 'Someone Else Lead',
  });
  await workspace.collection('tasks').doc('task-open').set({
    workspaceId,
    assigneeId: 'sales-user',
    status: 'open',
    title: 'Call back',
  });
  await workspace.collection('tasks').doc('task-done').set({
    workspaceId,
    assigneeId: 'sales-user',
    status: 'completed',
    title: 'Already handled',
  });

  const released = await new FirestoreInvitationStore(
    firestore,
  ).releaseRepresentativeWork({
    workspaceId,
    userId: 'sales-user',
    actingUserId: adminUserId,
    at: now,
  });

  assert.deepEqual(released, {contacts: 1, tasks: 1});

  const owned = await workspace.collection('contacts').doc('contact-one').get();
  assert.equal(owned.data()?.ownerId, null);
  assert.equal(owned.data()?.updatedByUserId, adminUserId);

  const untouched = await workspace
    .collection('contacts')
    .doc('contact-two')
    .get();
  assert.equal(untouched.data()?.ownerId, 'another-user');

  const openTask = await workspace.collection('tasks').doc('task-open').get();
  assert.equal(openTask.data()?.assigneeId, adminUserId);

  const doneTask = await workspace.collection('tasks').doc('task-done').get();
  assert.equal(doneTask.data()?.assigneeId, 'sales-user');
});

test('revoking releases the email so the address can be invited again', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'returning@example.com',
  });
  const firstUserId = String((await onlyInvitation()).data()?.invitedUserId);
  const store = new FirestoreInvitationStore(firestore);
  await store.acceptInvitation({
    workspaceId,
    invitationId: created.invitationId,
    userId: firstUserId,
    displayName: 'Sales Rep',
    at: now,
  });

  await store.updateSalesRepresentativeStatus({
    workspaceId,
    actingUserId: adminUserId,
    userId: firstUserId,
    action: 'revoke',
    at: now,
  });

  assert.equal(await memberStatus(firstUserId), 'revoked');
  const locks = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('invitationLocks')
    .get();
  assert.equal(locks.empty, true);

  await auth.deleteUser(firstUserId);
  const reinvited = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'returning@example.com',
  });

  assert.notEqual(reinvited.invitationId, created.invitationId);
  assert.equal(reinvited.status, 'pending');
  assert.equal(await memberStatus(firstUserId), 'revoked');
});

test('suspending leaves the email lock in place', async () => {
  await seedMembership(adminUserId, 'admin', 'active');
  const service = makeService(new RecordingSender());
  const created = await service.create({
    actingUserId: adminUserId,
    workspaceId,
    email: 'paused@example.com',
  });
  const invitedUserId = String((await onlyInvitation()).data()?.invitedUserId);
  const store = new FirestoreInvitationStore(firestore);
  await store.acceptInvitation({
    workspaceId,
    invitationId: created.invitationId,
    userId: invitedUserId,
    displayName: 'Sales Rep',
    at: now,
  });

  await store.updateSalesRepresentativeStatus({
    workspaceId,
    actingUserId: adminUserId,
    userId: invitedUserId,
    action: 'suspend',
    at: now,
  });

  const locks = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('invitationLocks')
    .get();
  assert.equal(locks.size, 1);
  assert.equal(await memberStatus(invitedUserId), 'suspended');
});

test('removes a just-created Auth user when atomic Firestore creation fails', async () => {
  const failingStore: InvitationStore = {
    requireActiveAdmin: async () => {},
    findPendingInvitation: async () => null,
    findInvitation: async () => {
      throw new Error('Not used');
    },
    createInvitation: async () => {
      throw new Error('Firestore transaction failed');
    },
    reserveEmailRequestAttempt: async () => 'reserved',
    markEmailRequestAccepted: async () => {},
    markEmailRequestFailed: async () => {},
    markExpired: async () => {},
    revokePendingInvitation: async () => {},
    acceptInvitation: async () => 'accepted',
    updateSalesRepresentativeStatus: async () => {},
  };
  const service = new CreateWorkspaceInvitationService({
    auth,
    invitationStore: failingStore,
    emailSender: new RecordingSender(),
    now: () => now,
  });

  await assert.rejects(
    service.create({
      actingUserId: adminUserId,
      workspaceId,
      email: 'cleanup@example.com',
    }),
    /Firestore transaction failed/,
  );
  await assertUserMissing('cleanup@example.com');
});

function makeService(emailSender: InvitationEmailSender, clock: () => Date = () => now) {
  return new CreateWorkspaceInvitationService({
    auth,
    invitationStore: new FirestoreInvitationStore(firestore),
    emailSender,
    now: clock,
  });
}

async function seedMembership(
  userId: string,
  role: 'admin' | 'sales_rep',
  status: 'active' | 'suspended',
) {
  await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc(userId)
    .set({ workspaceId, userId, role, status });
}

async function onlyInvitation() {
  const invitations = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('invitations')
    .get();
  assert.equal(invitations.size, 1);
  return invitations.docs[0]!;
}

async function memberStatus(userId: string) {
  const member = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc(userId)
    .get();
  return member.data()?.status;
}

async function assertUserMissing(email: string) {
  await assert.rejects(
    auth.getUserByEmail(email),
    (error: unknown) =>
      typeof error === 'object' && error !== null && 'code' in error &&
      error.code === 'auth/user-not-found',
  );
}

async function clearFirestore() {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(
    `http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
}

async function clearAuth() {
  const host = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${projectId}/accounts`, {
    method: 'DELETE',
  });
}

function pick(
  value: Record<string, unknown> | undefined,
  keys: readonly string[],
) {
  return Object.fromEntries(keys.map((key) => [key, value?.[key]]));
}

class RecordingSender implements InvitationEmailSender {
  constructor({ shouldFail = false }: { shouldFail?: boolean } = {}) {
    this.shouldFail = shouldFail;
  }

  shouldFail: boolean;
  readonly messages: string[] = [];

  async requestPasswordSetup(email: string): Promise<void> {
    this.messages.push(email);
    if (this.shouldFail) throw new Error('Provider unavailable');
  }
}
