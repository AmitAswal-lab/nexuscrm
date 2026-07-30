import assert from 'node:assert/strict';
import test, {afterEach, before} from 'node:test';

import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import type {Request, Response} from 'express';

import {handleSharedDocumentRequest} from './serve_shared_document.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-nexuscrm';
const workspaceId = 'workspace-one';
const token = 'a'.repeat(43);

if (getApps().length === 0) initializeApp({projectId});

const firestore = getFirestore();

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
});

afterEach(async () => {
  await clearFirestore();
});

test('refuses anything but a read', async () => {
  const response = await call({method: 'POST'});

  assert.equal(response.statusCode, 405);
});

test('refuses a malformed token without touching the database', async () => {
  assert.equal((await call({query: {}})).statusCode, 400);
  assert.equal((await call({query: {token: 'short'}})).statusCode, 400);
});

test('refuses a token that matches no share', async () => {
  const response = await call();

  assert.equal(response.statusCode, 404);
});

test('refuses a revoked share', async () => {
  await seedDocument();
  await seedShare({revokedAt: Timestamp.now()});

  const response = await call();

  assert.equal(response.statusCode, 410);
  assert.match(response.body, /revoked/i);
});

test('refuses an expired share', async () => {
  await seedDocument();
  await seedShare({
    expiresAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00.000Z')),
  });

  const response = await call();

  assert.equal(response.statusCode, 410);
  assert.match(response.body, /expired/i);
});

test('refuses a share whose document was withdrawn', async () => {
  await seedDocument({isRetired: true});
  await seedShare();

  const response = await call();

  assert.equal(response.statusCode, 410);
  assert.match(response.body, /withdrawn/i);
});

test('does not count an open when the share is rejected', async () => {
  await seedDocument();
  await seedShare({revokedAt: Timestamp.now()});

  await call();

  const share = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('documentShares')
    .doc('share-one')
    .get();

  assert.equal(share.data()?.openCount, 0);
});

interface Recorded {
  statusCode: number;
  body: string;
}

async function call({
  method = 'GET',
  query = {token},
}: {
  method?: string;
  query?: Record<string, string>;
} = {}): Promise<Recorded> {
  const recorded: Recorded = {statusCode: 200, body: ''};
  const response = {
    status(code: number) {
      recorded.statusCode = code;
      return this;
    },
    send(payload: string) {
      recorded.body = String(payload);
      return this;
    },
    setHeader() {
      return this;
    },
    end() {
      return this;
    },
  } as unknown as Response;

  await handleSharedDocumentRequest(
    {method, query} as unknown as Request,
    response,
  );

  return recorded;
}

async function seedDocument(
  overrides: Record<string, unknown> = {},
): Promise<void> {
  await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('documents')
    .doc('brochure')
    .set({
      workspaceId,
      title: 'Product brochure',
      storagePath: `workspaces/${workspaceId}/documents/brochure`,
      contentType: 'application/pdf',
      sizeBytes: 2048,
      isRetired: false,
      ...overrides,
    });
}

async function seedShare(
  overrides: Record<string, unknown> = {},
): Promise<void> {
  await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('documentShares')
    .doc('share-one')
    .set({
      workspaceId,
      documentId: 'brochure',
      documentTitle: 'Product brochure',
      contactId: 'owned-lead',
      contactName: 'Owned Lead',
      channel: 'whatsapp',
      token,
      sharedByUserId: 'sales-user',
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00.000Z')),
      revokedAt: null,
      openCount: 0,
      lastOpenedAt: null,
      ...overrides,
    });
}

async function clearFirestore(): Promise<void> {
  await firestore.recursiveDelete(
    firestore.collection('workspaces').doc(workspaceId),
  );
}
