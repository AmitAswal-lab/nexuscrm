import { getAuth } from 'firebase-admin/auth';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret, defineString } from 'firebase-functions/params';

import { ResendInvitationEmailSender } from './email/resend_invitation_email_sender.js';
import { CreateWorkspaceInvitationService } from './invitations/create_workspace_invitation.js';
import { FirestoreInvitationStore } from './invitations/firestore_invitation_store.js';
import { InvitationError } from './invitations/invitation_error.js';

if (getApps().length === 0) initializeApp();

const resendApiKey = defineSecret('RESEND_API_KEY');
const invitationFromEmail = defineString('INVITATION_FROM_EMAIL');
const passwordSetupContinueUrl = defineString(
  'INVITATION_PASSWORD_SETUP_CONTINUE_URL',
);
const callableOptions = {
  region: 'us-central1' as const,
  memory: '256MiB' as const,
  timeoutSeconds: 20,
  minInstances: 0,
  maxInstances: 2,
  concurrency: 5,
  secrets: [resendApiKey],
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

function invitationService() {
  return new CreateWorkspaceInvitationService({
    auth: getAuth(),
    invitationStore: new FirestoreInvitationStore(getFirestore()),
    emailSender: new ResendInvitationEmailSender({
      apiKey: resendApiKey.value(),
      from: invitationFromEmail.value(),
    }),
    passwordSetupLinkFactory: {
      create: (email, settings) => getAuth().generatePasswordResetLink(email, settings),
    },
    passwordSetupContinueUrl: passwordSetupContinueUrl.value(),
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
