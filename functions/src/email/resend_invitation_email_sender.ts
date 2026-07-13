import type { InvitationEmail, InvitationEmailSender } from './invitation_email_sender.js';

type Fetch = typeof fetch;

export class ResendInvitationEmailSender implements InvitationEmailSender {
  constructor({
    apiKey,
    from,
    fetcher = fetch,
  }: {
    apiKey: string;
    from: string;
    fetcher?: Fetch;
  }) {
    if (apiKey.trim().length === 0) {
      throw new Error('The invitation email provider is not configured.');
    }
    if (from.trim().length === 0) {
      throw new Error('The invitation sender address is not configured.');
    }

    this.#apiKey = apiKey;
    this.#from = from;
    this.#fetch = fetcher;
  }

  readonly #apiKey: string;
  readonly #from: string;
  readonly #fetch: Fetch;

  async send({ to, passwordSetupLink }: InvitationEmail): Promise<void> {
    const response = await this.#fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.#apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.#from,
        to: [to],
        subject: 'Set up your Nexus CRM account',
        text: [
          'You have been invited to Nexus CRM.',
          '',
          'Use this secure link to set your password:',
          passwordSetupLink,
          '',
          'After setting your password, sign in to complete your onboarding.',
        ].join('\n'),
      }),
      signal: AbortSignal.timeout(5000),
    });

    if (!response.ok) {
      throw new Error('Invitation email delivery was rejected.');
    }
  }
}
