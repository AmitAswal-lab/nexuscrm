import { getAuth } from 'firebase-admin/auth';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';

import { FirebaseAuthInvitationEmailSender } from './email/firebase_auth_invitation_email_sender.js';
import { CreateWorkspaceInvitationService } from './invitations/create_workspace_invitation.js';
import {
  FirestoreInvitationStore,
  type SalesRepresentativeAction,
} from './invitations/firestore_invitation_store.js';
import { InvitationError } from './invitations/invitation_error.js';

if (getApps().length === 0) initializeApp();

// Firebase's web API key identifies this Firebase Auth project to its
// documented password-reset endpoint. It is public application configuration,
// not an email-provider credential or a secret.
const invitationAuthWebApiKey = defineString('INVITATION_AUTH_WEB_API_KEY');
const callableOptions = {
  region: 'us-central1' as const,
  memory: '256MiB' as const,
  timeoutSeconds: 20,
  minInstances: 0,
  maxInstances: 2,
  concurrency: 5,
};
const accessCallableOptions = {
  region: 'us-central1' as const,
  memory: '256MiB' as const,
  timeoutSeconds: 20,
  minInstances: 0,
  maxInstances: 2,
  concurrency: 5,
};

export const createWorkspaceInvitation = onCall(
  callableOptions,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to continue.');
    }

    try {
      const data = request.data as Record<string, unknown>;
      const service = invitationService();

      return await service.create({
        actingUserId: request.auth.uid,
        workspaceId: stringField(data, 'workspaceId'),
        email: stringField(data, 'email'),
      });
    } catch (error) {
      if (error instanceof InvitationError) {
        throw new HttpsError(error.code, error.message);
      }
      throw new HttpsError('internal', 'Unable to create the invitation.');
    }
  },
);

export const resendWorkspaceInvitation = onCall(callableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }

  try {
    const data = request.data as Record<string, unknown>;
    return await invitationService().resend({
      actingUserId: request.auth.uid,
      workspaceId: stringField(data, 'workspaceId'),
      invitationId: stringField(data, 'invitationId'),
    });
  } catch (error) {
    throw callableError(error);
  }
});

export const revokeWorkspaceInvitation = onCall(callableOptions, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }

  try {
    const data = request.data as Record<string, unknown>;
    await invitationService().revoke({
      actingUserId: request.auth.uid,
      workspaceId: stringField(data, 'workspaceId'),
      invitationId: stringField(data, 'invitationId'),
    });
    return {status: 'revoked'};
  } catch (error) {
    throw callableError(error);
  }
});

export const acceptWorkspaceInvitation = onCall(
  accessCallableOptions,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to continue.');
    }

    try {
      const data = request.data as Record<string, unknown>;
      const outcome = await new FirestoreInvitationStore(
        getFirestore(),
      ).acceptInvitation({
        workspaceId: documentIdField(data, 'workspaceId'),
        invitationId: documentIdField(data, 'invitationId'),
        userId: request.auth.uid,
        displayName: displayNameField(data),
        at: new Date(),
      });
      if (outcome === 'expired') {
        throw new InvitationError('failed-precondition', 'This invitation has expired.');
      }
      return {status: 'accepted'};
    } catch (error) {
      throw callableError(error);
    }
  },
);

export const updateSalesRepresentativeStatus = onCall(
  accessCallableOptions,
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to continue.');
    }

    try {
      const data = request.data as Record<string, unknown>;
      const action = salesRepresentativeAction(data);
      const userId = documentIdField(data, 'userId');
      const workspaceId = documentIdField(data, 'workspaceId');
      const at = new Date();
      const store = new FirestoreInvitationStore(getFirestore());
      await store.updateSalesRepresentativeStatus({
        workspaceId,
        actingUserId: request.auth.uid,
        userId,
        action,
        at,
      });

      if (action !== 'revoke') {
        return {status: 'updated'};
      }

      const released = await store.releaseRepresentativeWork({
        workspaceId,
        userId,
        actingUserId: request.auth.uid,
        at,
      });
      await deleteRevokedAccount(userId);

      return {status: 'updated', released};
    } catch (error) {
      throw callableError(error);
    }
  },
);

async function deleteRevokedAccount(userId: string): Promise<void> {
  try {
    await getAuth().deleteUser(userId);
  } catch (error) {
    if (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === 'auth/user-not-found'
    ) {
      return;
    }
    throw error;
  }
}

function invitationService() {
  return new CreateWorkspaceInvitationService({
    auth: getAuth(),
    invitationStore: new FirestoreInvitationStore(getFirestore()),
    emailSender: new FirebaseAuthInvitationEmailSender({
      apiKey: invitationAuthWebApiKey.value(),
    }),
  });
}

function callableError(error: unknown): HttpsError {
  if (error instanceof InvitationError) {
    return new HttpsError(error.code, error.message);
  }
  return new HttpsError('internal', 'Unable to complete the invitation action.');
}

function stringField(data: Record<string, unknown>, field: string): string {
  const value = data[field];
  if (typeof value !== 'string') {
    throw new InvitationError('invalid-argument', `Invalid ${field}.`);
  }
  return value;
}

function displayNameField(data: Record<string, unknown>): string {
  const value = stringField(data, 'displayName').trim().replace(/\s+/g, ' ');
  if (value.length === 0 || value.length > 80) {
    throw new InvitationError('invalid-argument', 'Invalid displayName.');
  }
  return value;
}

function documentIdField(data: Record<string, unknown>, field: string): string {
  const value = stringField(data, field).trim();
  if (value.length === 0 || value.includes('/')) {
    throw new InvitationError('invalid-argument', `Invalid ${field}.`);
  }
  return value;
}

function salesRepresentativeAction(
  data: Record<string, unknown>,
): SalesRepresentativeAction {
  const action = stringField(data, 'action');
  if (action === 'suspend' || action === 'reactivate' || action === 'revoke') {
    return action;
  }
  throw new InvitationError('invalid-argument', 'Invalid membership action.');
}
