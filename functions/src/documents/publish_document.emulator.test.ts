import assert from 'node:assert/strict';
import test, {afterEach, before} from 'node:test';

import {getAuth} from 'firebase-admin/auth';
import {getApps, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import type {Request} from 'firebase-functions/v2/https';
import type {Response} from 'express';

import {handlePublishDocumentRequest} from './publish_document.js';

const projectId = process.env.GCLOUD_PROJECT ?? 'demo-nexuscrm';
const workspaceId = 'workspace-documents';

if (getApps().length === 0) initializeApp({projectId});

const firestore = getFirestore();

async function emulatorIdToken(uid: string): Promise<string> {
  try {
    await getAuth().createUser({uid});
  } catch {
    // Already present from an earlier test.
  }

  const customToken = await getAuth().createCustomToken(uid);
  const response = await fetch(
    `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}` +
      '/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken' +
      '?key=emulator-unused',
    {
      method: 'POST',
      headers: {'content-type': 'application/json'},
      body: JSON.stringify({token: customToken, returnSecureToken: true}),
    },
  );
  const payload = (await response.json()) as {idToken?: string};

  assert.ok(payload.idToken, 'the auth emulator returned no ID token');
  return payload.idToken;
}

before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
});

afterEach(async () => {
  await firestore.recursiveDelete(
    firestore.collection('workspaces').doc(workspaceId),
  );
});

test('refuses anything but a post', async () => {
  const result = await call({method: 'GET'});

  assert.equal(result.statusCode, 405);
});

test('refuses a request with no bearer token', async () => {
  const result = await call({headers: {}});

  assert.equal(result.statusCode, 401);
});

test('refuses a request whose token cannot be verified', async () => {
  const result = await call({headers: {authorization: 'Bearer not-a-token'}});

  assert.equal(result.statusCode, 401);
});

test('refuses a missing workspace or title', async () => {
  assert.equal((await call({query: {title: 'Brochure'}})).statusCode, 400);
  assert.equal((await call({query: {workspaceId}})).statusCode, 400);
});

test('writes nothing when the caller is not an active admin', async () => {
  await seedMembership('sales_rep', 'active');

  const result = await call();

  assert.equal(result.statusCode, 403);
  assert.equal(await documentCount(), 0);
});

test('writes nothing when the admin has been revoked', async () => {
  await seedMembership('admin', 'revoked');

  const result = await call();

  assert.equal(result.statusCode, 403);
  assert.equal(await documentCount(), 0);
});

test('writes nothing when the caller has no membership at all', async () => {
  const result = await call();

  assert.equal(result.statusCode, 403);
  assert.equal(await documentCount(), 0);
});

test('refuses an empty body and a body over the ceiling', async () => {
  await seedMembership('admin', 'active');

  assert.equal((await call({body: Buffer.alloc(0)})).statusCode, 400);
  assert.equal(
    (await call({body: Buffer.alloc(10 * 1024 * 1024 + 1)})).statusCode,
    413,
  );
  assert.equal(await documentCount(), 0);
});

interface Recorded {
  statusCode: number;
  payload: Record<string, unknown>;
}

async function call({
  method = 'POST',
  headers,
  query = {workspaceId, title: 'Product brochure'},
  body = Buffer.from([1, 2, 3, 4]),
}: {
  method?: string;
  headers?: Record<string, string>;
  query?: Record<string, string>;
  body?: Buffer;
} = {}): Promise<Recorded> {
  const resolved =
    headers ??
    {authorization: `Bearer ${await emulatorIdToken('admin-user')}`};
  const recorded: Recorded = {statusCode: 200, payload: {}};
  const response = {
    status(code: number) {
      recorded.statusCode = code;
      return this;
    },
    json(payload: Record<string, unknown>) {
      recorded.payload = payload;
      return this;
    },
  } as unknown as Response;

  await handlePublishDocumentRequest(
    {
      method,
      headers: {'content-type': 'application/pdf', ...resolved},
      query,
      rawBody: body,
    } as unknown as Request,
    response,
  );

  return recorded;
}

async function seedMembership(role: string, status: string): Promise<void> {
  await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc('admin-user')
    .set({userId: 'admin-user', workspaceId, role, status});
}

async function documentCount(): Promise<number> {
  const documents = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('documents')
    .get();

  return documents.size;
}
