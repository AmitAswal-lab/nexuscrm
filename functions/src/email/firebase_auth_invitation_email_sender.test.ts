import assert from 'node:assert/strict';
import test from 'node:test';

import { FirebaseAuthInvitationEmailSender } from './firebase_auth_invitation_email_sender.js';

test('requests Firebase Authentication password-reset email delivery', async () => {
  let requestedUrl: string | undefined;
  let capturedRequest: RequestInit | undefined;
  const sender = new FirebaseAuthInvitationEmailSender({
    apiKey: 'firebase-web-api-key',
    fetcher: async (url, request) => {
      requestedUrl = String(url);
      capturedRequest = request;
      return new Response(JSON.stringify({email: 'rep@example.com'}), {
        status: 200,
      });
    },
  });

  await sender.requestPasswordSetup('rep@example.com');

  assert.equal(
    requestedUrl,
    'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=firebase-web-api-key',
  );
  assert.equal(capturedRequest?.method, 'POST');
  assert.deepEqual(capturedRequest?.headers, {'Content-Type': 'application/json'});
  assert.deepEqual(JSON.parse(String(capturedRequest?.body)), {
    requestType: 'PASSWORD_RESET',
    email: 'rep@example.com',
  });
});

test('fails when Firebase Authentication rejects the email request', async () => {
  const sender = new FirebaseAuthInvitationEmailSender({
    apiKey: 'firebase-web-api-key',
    fetcher: async () => new Response(null, {status: 400}),
  });

  await assert.rejects(
    sender.requestPasswordSetup('rep@example.com'),
    /Firebase Authentication did not accept the email request/,
  );
});
