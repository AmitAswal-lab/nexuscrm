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

export const createWorkspaceInvitation = onCall(
  {
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 20,
    minInstances: 0,
    maxInstances: 2,
    concurrency: 5,
    secrets: [resendApiKey],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to continue.');
    }

    try {
      const data = request.data as Record<string, unknown>;
      const service = new CreateWorkspaceInvitationService({
        auth: getAuth(),
        invitationStore: new FirestoreInvitationStore(getFirestore()),
        emailSender: new ResendInvitationEmailSender({
          apiKey: resendApiKey.value(),
          from: invitationFromEmail.value(),
        }),
        passwordSetupLinkFactory: {
          create: (email, settings) =>
            getAuth().generatePasswordResetLink(email, settings),
        },
        passwordSetupContinueUrl: passwordSetupContinueUrl.value(),
      });

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

function stringField(data: Record<string, unknown>, field: string): string {
  const value = data[field];
  if (typeof value !== 'string') {
    throw new InvitationError('invalid-argument', `Invalid ${field}.`);
  }
  return value;
}
