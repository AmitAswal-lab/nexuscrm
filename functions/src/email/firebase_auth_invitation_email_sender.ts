import type { InvitationEmailSender } from './invitation_email_sender.js';

type Fetch = typeof fetch;

/**
 * Uses Firebase Authentication's standard password-reset email and default
 * Firebase-hosted action handler. This adapter intentionally receives no
 * custom action URL or sender configuration.
 */
export class FirebaseAuthInvitationEmailSender implements InvitationEmailSender {
  constructor({
    apiKey,
    fetcher = fetch,
  }: {
    apiKey: string;
    fetcher?: Fetch;
  }) {
    if (apiKey.trim().length === 0) {
      throw new Error('Firebase Authentication email delivery is not configured.');
    }

    this.#apiKey = apiKey;
    this.#fetch = fetcher;
  }

  readonly #apiKey: string;
  readonly #fetch: Fetch;

  async requestPasswordSetup(email: string): Promise<void> {
    const response = await this.#fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(this.#apiKey)}`,
      {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({requestType: 'PASSWORD_RESET', email}),
        signal: AbortSignal.timeout(5000),
      },
    );

    if (!response.ok) {
      throw new Error('Firebase Authentication did not accept the email request.');
    }
  }
}
