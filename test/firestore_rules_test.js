const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  where,
} = require('firebase/firestore');

const projectId = 'demo-nexuscrm';
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
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();

    await setDoc(doc(database, 'users', 'admin-user'), {
      email: 'admin@example.com',
    });
    await setDoc(doc(database, 'users', 'sales-user'), {
      email: 'sales@example.com',
    });
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'members', 'admin-user'),
      {
        userId: 'admin-user',
        workspaceId: 'workspace-one',
        role: 'admin',
        status: 'active',
      },
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'members', 'sales-user'),
      {
        userId: 'sales-user',
        workspaceId: 'workspace-one',
        role: 'sales_rep',
        status: 'active',
      },
    );
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

test('rejects unauthenticated profile reads', async () => {
  const database = testEnvironment.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(database, 'users', 'admin-user')));
});

test('allows a user to read only their own profile', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertSucceeds(getDoc(doc(database, 'users', 'admin-user')));
  await assertFails(getDoc(doc(database, 'users', 'sales-user')));
});

test('allows the authenticated user to query their memberships', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const memberships = query(
    collectionGroup(database, 'members'),
    where('userId', '==', 'admin-user'),
  );

  await assertSucceeds(getDocs(memberships));
});

test('rejects membership queries for another user', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const memberships = query(
    collectionGroup(database, 'members'),
    where('userId', '==', 'sales-user'),
  );

  await assertFails(getDocs(memberships));
});

test('rejects client writes to profiles and memberships', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertFails(
    setDoc(doc(database, 'users', 'admin-user'), {
      email: 'changed@example.com',
    }),
  );
  await assertFails(
    setDoc(
      doc(database, 'workspaces', 'workspace-one', 'members', 'admin-user'),
      {
        userId: 'admin-user',
        workspaceId: 'workspace-one',
        role: 'sales_rep',
        status: 'active',
      },
    ),
  );
});
