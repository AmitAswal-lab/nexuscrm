export interface InvitationEmail {
  readonly to: string;
  readonly passwordSetupLink: string;
}

export interface InvitationEmailSender {
  send(email: InvitationEmail): Promise<void>;
}
