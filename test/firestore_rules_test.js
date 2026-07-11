const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, test } = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
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
        displayName: 'Sales User',
        email: 'sales@example.com',
      },
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'members', 'other-sales'),
      {
        userId: 'other-sales',
        workspaceId: 'workspace-one',
        role: 'sales_rep',
        status: 'active',
        displayName: 'Other Sales',
        email: 'other@example.com',
      },
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'members', 'inactive-sales'),
      {
        userId: 'inactive-sales',
        workspaceId: 'workspace-one',
        role: 'sales_rep',
        status: 'suspended',
        displayName: 'Inactive Sales',
        email: 'inactive@example.com',
      },
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'contacts', 'owned-lead'),
      leadData({ ownerId: 'sales-user' }),
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'contacts', 'other-lead'),
      leadData({ ownerId: 'other-sales' }),
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'tasks', 'owned-task'),
      taskData({ contactId: 'owned-lead', assigneeId: 'sales-user' }),
    );
    await setDoc(
      doc(database, 'workspaces', 'workspace-one', 'tasks', 'other-task'),
      taskData({ contactId: 'other-lead', assigneeId: 'other-sales' }),
    );
    await setDoc(
      doc(
        database,
        'workspaces',
        'workspace-one',
        'activities',
        'owned-call-note',
      ),
      callNoteData({ contactId: 'owned-lead', actorUserId: 'sales-user' }),
    );
    await setDoc(
      doc(
        database,
        'workspaces',
        'workspace-one',
        'activities',
        'other-call-note',
      ),
      callNoteData({ contactId: 'other-lead', actorUserId: 'other-sales' }),
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

test('allows an admin to read all workspace contacts', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertSucceeds(
    getDocs(collection(database, 'workspaces', 'workspace-one', 'contacts')),
  );
});

test('allows a sales rep to query only contacts assigned to them', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const ownedContacts = query(
    collection(database, 'workspaces', 'workspace-one', 'contacts'),
    where('ownerId', '==', 'sales-user'),
  );

  await assertSucceeds(getDocs(ownedContacts));
  await assertFails(
    getDoc(
      doc(database, 'workspaces', 'workspace-one', 'contacts', 'other-lead'),
    ),
  );
});

test('allows valid lead creation for admin and sales roles', async () => {
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();

  await assertSucceeds(
    setDoc(
      doc(adminDatabase, 'workspaces', 'workspace-one', 'contacts', 'admin-new'),
      leadData({
        actorUserId: 'admin-user',
        ownerId: 'other-sales',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(salesDatabase, 'workspaces', 'workspace-one', 'contacts', 'sales-new'),
      leadData({
        actorUserId: 'sales-user',
        ownerId: 'sales-user',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('rejects invalid sales ownership and inactive assignees', async () => {
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertFails(
    setDoc(
      doc(
        salesDatabase,
        'workspaces',
        'workspace-one',
        'contacts',
        'wrong-owner',
      ),
      leadData({
        actorUserId: 'sales-user',
        ownerId: 'other-sales',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(
        adminDatabase,
        'workspaces',
        'workspace-one',
        'contacts',
        'inactive-owner',
      ),
      leadData({
        actorUserId: 'admin-user',
        ownerId: 'inactive-sales',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('allows owners and admins to update contacts safely', async () => {
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const reference = doc(
    salesDatabase,
    'workspaces',
    'workspace-one',
    'contacts',
    'owned-lead',
  );

  await assertSucceeds(
    updateDoc(reference, {
      fullName: 'Updated Lead',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertSucceeds(
    updateDoc(
      doc(
        adminDatabase,
        'workspaces',
        'workspace-one',
        'contacts',
        'other-lead',
      ),
      {
        ownerId: 'sales-user',
        updatedAt: serverTimestamp(),
        updatedByUserId: 'admin-user',
      },
    ),
  );
});

test('rejects sales reassignment and immutable field changes', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    database,
    'workspaces',
    'workspace-one',
    'contacts',
    'owned-lead',
  );

  await assertFails(
    updateDoc(reference, {
      ownerId: 'other-sales',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(
    updateDoc(reference, {
      createdByUserId: 'sales-user',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
});

test('allows atomic lead conversion and prevents reversing a client', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    database,
    'workspaces',
    'workspace-one',
    'contacts',
    'owned-lead',
  );

  await assertSucceeds(
    updateDoc(reference, {
      kind: 'client',
      leadStage: null,
      convertedAt: serverTimestamp(),
      convertedByUserId: 'sales-user',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(
    updateDoc(reference, {
      kind: 'lead',
      leadStage: 'new',
      convertedAt: null,
      convertedByUserId: null,
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
});

test('allows soft archive but rejects hard deletion', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    database,
    'workspaces',
    'workspace-one',
    'contacts',
    'owned-lead',
  );

  await assertSucceeds(
    updateDoc(reference, {
      isArchived: true,
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(deleteDoc(reference));
});

test('allows admins to read the active sales-assignee directory', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const activeSales = query(
    collection(database, 'workspaces', 'workspace-one', 'members'),
    where('role', '==', 'sales_rep'),
    where('status', '==', 'active'),
  );

  await assertSucceeds(getDocs(activeSales));
});

test('allows an admin to read all workspace tasks', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertSucceeds(
    getDocs(collection(database, 'workspaces', 'workspace-one', 'tasks')),
  );
});

test('allows a sales rep to query only tasks assigned to them', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const assignedTasks = query(
    collection(database, 'workspaces', 'workspace-one', 'tasks'),
    where('assigneeId', '==', 'sales-user'),
  );

  await assertSucceeds(getDocs(assignedTasks));
  await assertFails(
    getDoc(doc(database, 'workspaces', 'workspace-one', 'tasks', 'other-task')),
  );
});

test('allows valid task creation for admin and sales roles', async () => {
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();

  await assertSucceeds(
    setDoc(
      doc(adminDatabase, 'workspaces', 'workspace-one', 'tasks', 'admin-new'),
      taskData({
        actorUserId: 'admin-user',
        contactId: 'other-lead',
        assigneeId: 'other-sales',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(salesDatabase, 'workspaces', 'workspace-one', 'tasks', 'sales-new'),
      taskData({
        actorUserId: 'sales-user',
        contactId: 'owned-lead',
        assigneeId: 'sales-user',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('rejects invalid sales task assignment and inactive assignees', async () => {
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertFails(
    setDoc(
      doc(salesDatabase, 'workspaces', 'workspace-one', 'tasks', 'wrong-owner'),
      taskData({
        actorUserId: 'sales-user',
        contactId: 'other-lead',
        assigneeId: 'sales-user',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(salesDatabase, 'workspaces', 'workspace-one', 'tasks', 'wrong-assignee'),
      taskData({
        actorUserId: 'sales-user',
        contactId: 'owned-lead',
        assigneeId: 'other-sales',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(adminDatabase, 'workspaces', 'workspace-one', 'tasks', 'inactive-task'),
      taskData({
        actorUserId: 'admin-user',
        contactId: 'owned-lead',
        assigneeId: 'inactive-sales',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('allows safe task content updates and rejects sales reassignment', async () => {
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    salesDatabase,
    'workspaces',
    'workspace-one',
    'tasks',
    'owned-task',
  );

  await assertSucceeds(
    updateDoc(reference, {
      title: 'Call back the lead',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(
    updateDoc(reference, {
      assigneeId: 'other-sales',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
});

test('allows assigned users to complete and reopen tasks safely', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    database,
    'workspaces',
    'workspace-one',
    'tasks',
    'owned-task',
  );

  await assertSucceeds(
    updateDoc(reference, {
      status: 'completed',
      completionCount: 1,
      lastCompletedAt: serverTimestamp(),
      lastCompletedByUserId: 'sales-user',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertSucceeds(
    updateDoc(reference, {
      status: 'open',
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(
    updateDoc(reference, {
      status: 'completed',
      completionCount: 5,
      updatedAt: serverTimestamp(),
      updatedByUserId: 'sales-user',
    }),
  );
  await assertFails(deleteDoc(reference));
});

test('allows admins to read all workspace call notes', async () => {
  const database = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();

  await assertSucceeds(
    getDocs(collection(database, 'workspaces', 'workspace-one', 'activities')),
  );
});

test('allows sales reps to read call notes only for contacts they own', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const ownedCallNotes = query(
    collection(database, 'workspaces', 'workspace-one', 'activities'),
    where('contactId', '==', 'owned-lead'),
  );

  await assertSucceeds(getDocs(ownedCallNotes));
  await assertFails(
    getDoc(
      doc(
        database,
        'workspaces',
        'workspace-one',
        'activities',
        'other-call-note',
      ),
    ),
  );
});

test('allows valid call-note creation for admin and sales roles', async () => {
  const adminDatabase = testEnvironment
    .authenticatedContext('admin-user')
    .firestore();
  const salesDatabase = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();

  await assertSucceeds(
    setDoc(
      doc(
        adminDatabase,
        'workspaces',
        'workspace-one',
        'activities',
        'admin-call-note',
      ),
      callNoteData({
        actorUserId: 'admin-user',
        contactId: 'other-lead',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(
        salesDatabase,
        'workspaces',
        'workspace-one',
        'activities',
        'sales-call-note',
      ),
      callNoteData({
        actorUserId: 'sales-user',
        contactId: 'owned-lead',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('rejects invalid call-note ownership and actor spoofing', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();

  await assertFails(
    setDoc(
      doc(
        database,
        'workspaces',
        'workspace-one',
        'activities',
        'wrong-contact',
      ),
      callNoteData({
        actorUserId: 'sales-user',
        contactId: 'other-lead',
        useServerTimestamp: true,
      }),
    ),
  );
  await assertFails(
    setDoc(
      doc(
        database,
        'workspaces',
        'workspace-one',
        'activities',
        'spoofed-actor',
      ),
      callNoteData({
        actorUserId: 'admin-user',
        contactId: 'owned-lead',
        useServerTimestamp: true,
      }),
    ),
  );
});

test('keeps call notes append-only', async () => {
  const database = testEnvironment
    .authenticatedContext('sales-user')
    .firestore();
  const reference = doc(
    database,
    'workspaces',
    'workspace-one',
    'activities',
    'owned-call-note',
  );

  await assertFails(updateDoc(reference, { note: 'Changed after the call' }));
  await assertFails(deleteDoc(reference));
});

function leadData({
  actorUserId = 'admin-user',
  ownerId,
  useServerTimestamp = false,
} = {}) {
  const timestamp = useServerTimestamp
    ? serverTimestamp()
    : new Date('2026-01-01T00:00:00.000Z');

  return {
    workspaceId: 'workspace-one',
    kind: 'lead',
    fullName: 'Example Lead',
    companyName: null,
    email: 'lead@example.com',
    phone: null,
    notes: null,
    ownerId,
    leadStage: 'new',
    isArchived: false,
    createdByUserId: actorUserId,
    updatedByUserId: actorUserId,
    createdAt: timestamp,
    updatedAt: timestamp,
    convertedAt: null,
    convertedByUserId: null,
  };
}

function taskData({
  actorUserId = 'admin-user',
  contactId = 'owned-lead',
  assigneeId = 'sales-user',
  useServerTimestamp = false,
} = {}) {
  const timestamp = useServerTimestamp
    ? serverTimestamp()
    : new Date('2026-01-01T00:00:00.000Z');

  return {
    workspaceId: 'workspace-one',
    contactId,
    kind: 'follow_up',
    title: 'Call the lead',
    notes: null,
    assigneeId,
    dueOn: '2026-01-02',
    status: 'open',
    completionCount: 0,
    lastCompletedAt: null,
    lastCompletedByUserId: null,
    createdByUserId: actorUserId,
    updatedByUserId: actorUserId,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function callNoteData({
  actorUserId = 'admin-user',
  contactId = 'owned-lead',
  useServerTimestamp = false,
} = {}) {
  return {
    workspaceId: 'workspace-one',
    type: 'call_note',
    contactId,
    outcome: 'connected',
    note: 'Discussed the proposal',
    actorUserId,
    createdAt: useServerTimestamp
      ? serverTimestamp()
      : new Date('2026-01-01T00:00:00.000Z'),
    nextTaskId: null,
  };
}
