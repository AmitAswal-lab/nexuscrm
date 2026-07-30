const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');

const {
  assertFails,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const { doc, setDoc } = require('firebase/firestore');
const {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
} = require('firebase/storage');

const projectId = 'demo-nexuscrm';
const documentPath = 'workspaces/workspace-one/documents/brochure';
const bytes = new Uint8Array([1, 2, 3, 4]);
const metadata = { contentType: 'application/pdf' };

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '..', 'firestore.rules'),
        'utf8',
      ),
    },
    storage: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '..', 'storage.rules'),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.clearStorage();

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'workspaces',
        'workspace-one',
        'members',
        'admin-user',
      ),
      {
        userId: 'admin-user',
        workspaceId: 'workspace-one',
        role: 'admin',
        status: 'active',
      },
    );
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

// Documents move through Cloud Functions using the Admin SDK, which bypasses
// these rules. Every client path must therefore be closed, including for the
// administrator who published the document.
test('refuses uploads from every client, administrator included', async () => {
  const admin = testEnvironment.authenticatedContext('admin-user').storage();
  const stranger = testEnvironment.authenticatedContext('nobody').storage();
  const anonymous = testEnvironment.unauthenticatedContext().storage();

  await assertFails(uploadBytes(ref(admin, documentPath), bytes, metadata));
  await assertFails(uploadBytes(ref(stranger, documentPath), bytes, metadata));
  await assertFails(uploadBytes(ref(anonymous, documentPath), bytes, metadata));
});

test('refuses downloads from every client, administrator included', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), documentPath), bytes, metadata);
  });

  const admin = testEnvironment.authenticatedContext('admin-user').storage();
  const anonymous = testEnvironment.unauthenticatedContext().storage();

  await assertFails(getBytes(ref(admin, documentPath)));
  await assertFails(getBytes(ref(anonymous, documentPath)));
});

test('refuses deletion from every client', async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), documentPath), bytes, metadata);
  });

  const admin = testEnvironment.authenticatedContext('admin-user').storage();

  await assertFails(deleteObject(ref(admin, documentPath)));
});

test('refuses access anywhere else in the bucket', async () => {
  const admin = testEnvironment.authenticatedContext('admin-user').storage();

  await assertFails(
    uploadBytes(ref(admin, 'anything/at/all'), bytes, metadata),
  );
  await assertFails(getBytes(ref(admin, 'anything/at/all')));
});
