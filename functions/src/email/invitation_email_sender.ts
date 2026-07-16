export interface InvitationEmailSender {
  /**
   * Asks the configured provider to begin its password-setup email flow for an
   * existing Firebase Authentication user. A resolved request means only that
   * the provider accepted it; it does not prove inbox delivery or that the
   * recipient opened the email.
   */
  requestPasswordSetup(email: string): Promise<void>;
}
