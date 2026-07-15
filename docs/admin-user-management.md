# Admin user management foundation

## Membership lifecycle

Membership status is one of `invited`, `active`, `suspended`, or `revoked`.

Backend-owned membership records retain `invitationId`, `createdAt`,
`createdByUserId`, `updatedAt`, `updatedByUserId`, `statusChangedAt`, and
`statusChangedByUserId`, so every administrative action is attributable.

| From | Valid next states |
|---|---|
| invited | active, revoked |
| active | suspended, revoked |
| suspended | active, revoked |
| revoked | none |

Only trusted backend code will perform these transitions. `active` is the only
state that grants workspace access, so suspension and revocation take effect on
the next Firestore authorization check and membership session update.

## Invitation lifecycle

Invitations live at `workspaces/{workspaceId}/invitations/{invitationId}` with
the backend-owned fields `email`, `role`, `status`, `invitedByUserId`,
`createdAt`, `updatedAt`, `expiresAt`, `lastSentAt`, `resendCount`, and
acceptance/revocation audit fields.

An invitation progresses from `pending` to exactly one terminal state:
`accepted`, `expired`, or `revoked`. A resend updates only a still-pending
invitation's send audit fields; an expired, accepted, or revoked invitation is
never reused. Backend transactions will prevent duplicate pending invitations
for the same normalized workspace email and make acceptance single-use.

## Authorization foundation

Administrators can read workspace membership and invitation management data.
Sales representatives cannot read invitations. All client writes to membership
and invitation documents are denied, including activation, role changes,
status changes, and audit fields. Future invitation delivery and acceptance
will be implemented with backend-trusted code, not Cloud Firestore clients.

The `invitations` index supports administrator status/newest-first queries.

## Trusted invitation delivery (local implementation)

`createWorkspaceInvitation` is a callable Cloud Function that accepts only a
workspace ID and email from the app. It derives the acting user from Firebase
Authentication, verifies that the user is an active administrator for that
workspace, and fixes the new member role as `sales_rep`.

The Function normalizes the email and uses a backend-only SHA-256 email lock to
prevent duplicate pending invitations. It rejects an email that already belongs
to a Firebase Authentication user, so an account from another workspace cannot
be silently reused. For a new email, it creates an enabled Auth user with a
server-generated password that is never returned, then atomically creates the
invited membership, invitation, audit fields, expiry, and lock in Firestore. If
that Firestore transaction fails, it compensates by deleting the just-created
Auth user.

Invitation delivery is behind the `InvitationEmailSender` abstraction. The
production adapter targets Resend, but its API key and sender address are
Firebase Function configuration, not repository values. A password-setup link
is generated with Firebase Authentication and sent only to the provider. The
callable response contains only the invitation ID, normalized email, pending
status, invitation expiry, and `sent` or `failed` delivery status.

An invitation is valid for seven days. Firebase password-reset action-code
expiry is managed by Firebase rather than by the Function; a failed delivery
can be safely retried with the same invocation, which generates a fresh link
without creating another Auth user, membership, or invitation. The redirect
uses the required `INVITATION_PASSWORD_SETUP_CONTINUE_URL` configuration value;
it must be an HTTPS domain authorized in Firebase Authentication. Password
completion, invitation acceptance, and membership activation remain deferred
to representative onboarding.

## Invitation management workflow (local implementation)

The Team page separates existing members from pending invitations, preventing
the invited membership record from appearing as a duplicate team member. An
administrator can open an invite-by-email page, see successful or failed
delivery state, retry a failed delivery, resend a pending invitation, or revoke
a pending invitation. The UI shows only email addresses and human-readable
states; it does not expose Firebase user IDs.

`resendWorkspaceInvitation` and `revokeWorkspaceInvitation` are trusted
callables. Resend first reserves a delivery attempt inside a Firestore
transaction. A pending send blocks concurrent callers, and the backend applies
a 60-second rate limit between attempts. Every successful resend creates a
fresh Firebase password-setup link, while failures leave the same invitation,
membership, Auth user, and audit trail in place for a later retry.

Revocation is also transactional. It changes the invitation and its email lock
only when that specific invitation is pending. It changes a membership only
when the membership has the exact matching `invitationId` and is still
`invited`; an existing `active` representative is never revoked because of an
old invitation sharing their email address. Invitation expiry, delivery state,
and all audit fields remain backend-owned because Firestore client writes are
denied.

No onboarding, invitation acceptance, password completion, membership
activation, secrets, provider configuration, billing change, or deployment is
included in this checkpoint.

### Deployment prerequisites

Do not deploy this Function until all of the following are complete for
`nexuscrm-dev-amitaswal` only:

1. Upgrade the development project to Blaze and add a Cloud Billing budget
   alert with agreed recipients and thresholds.
2. Verify the Resend sender domain and configure `INVITATION_FROM_EMAIL`.
3. Store `RESEND_API_KEY` with `firebase functions:secrets:set`; never place it
   in source control or a local `.env` file.
4. Configure `INVITATION_PASSWORD_SETUP_CONTINUE_URL` as an authorized Firebase
   Authentication domain and verify the hosted password-reset flow.
5. Run `npm run test:functions`, `npm run test:firestore-rules`,
   `flutter analyze`, and `flutter test`, then manually review delivery using
   a development-only recipient.

### Dependency advisory

As of 2026-07-13, `npm audit --omit=dev` reports nine moderate transitive
advisories in the Firebase Admin dependency tree. The available automated fix
would force a breaking downgrade of Firebase Admin, so it was not applied.
Re-run and review the production dependency audit before the first deployment.
