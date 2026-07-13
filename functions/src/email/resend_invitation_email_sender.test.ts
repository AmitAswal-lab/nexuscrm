import assert from 'node:assert/strict';
import test from 'node:test';

import { ResendInvitationEmailSender } from './resend_invitation_email_sender.js';

test('sends only the expected invitation message to Resend', async () => {
  let capturedRequest: RequestInit | undefined;
  const sender = new ResendInvitationEmailSender({
    apiKey: 'test-key',
    from: 'Nexus CRM <invites@example.com>',
    fetcher: async (_, request) => {
      capturedRequest = request;
      return new Response(null, { status: 200 });
    },
  });

  await sender.send({
    to: 'rep@example.com',
    passwordSetupLink: 'https://example.com/setup-link',
  });

  assert.equal(capturedRequest?.method, 'POST');
  assert.deepEqual(capturedRequest?.headers, {
    Authorization: 'Bearer test-key',
    'Content-Type': 'application/json',
  });
  assert.deepEqual(JSON.parse(String(capturedRequest?.body)), {
    from: 'Nexus CRM <invites@example.com>',
    to: ['rep@example.com'],
    subject: 'Set up your Nexus CRM account',
    text: [
      'You have been invited to Nexus CRM.',
      '',
      'Use this secure link to set your password:',
      'https://example.com/setup-link',
      '',
      'After setting your password, sign in to complete your onboarding.',
    ].join('\n'),
  });
});

test('fails safely when Resend rejects delivery', async () => {
  const sender = new ResendInvitationEmailSender({
    apiKey: 'test-key',
    from: 'Nexus CRM <invites@example.com>',
    fetcher: async () => new Response(null, { status: 400 }),
  });

  await assert.rejects(
    sender.send({
      to: 'rep@example.com',
      passwordSetupLink: 'https://example.com/setup-link',
    }),
    /Invitation email delivery was rejected/,
  );
});
