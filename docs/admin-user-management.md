# Admin user management

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

Only trusted backend code performs these transitions. An active administrator
can suspend, reactivate, or revoke only sales representatives; they cannot
change an administrator, themselves, an invited membership, or an already
revoked membership. `active` is the only state that grants workspace access, so
suspension and revocation take effect on the next Firestore authorization check
and membership session update.

## Invitation lifecycle

Invitations live at `workspaces/{workspaceId}/invitations/{invitationId}` with
the backend-owned fields `email`, `role`, `status`, `emailRequestStatus`,
`emailRequestAttempts`, `invitedByUserId`, `createdAt`, `updatedAt`,
`expiresAt`, `lastEmailRequestAt`,
`lastEmailRequestAcceptedAt`, `resendRequestCount`, and
acceptance/revocation audit fields.

An invitation progresses from `pending` to exactly one terminal state:
`accepted`, `expired`, or `revoked`. A resend updates only a still-pending
invitation's email-request audit fields; an expired, accepted, or revoked
invitation is never reused. Backend transactions prevent duplicate pending
invitations for the same normalized workspace email and make acceptance
single-use.

## Authorization foundation

Administrators can read workspace membership and invitation management data.
Sales representatives cannot read invitations. All client writes to membership
and invitation documents are denied, including activation, role changes,
status changes, and audit fields. Invitation email requests and acceptance use
backend-trusted code, not Cloud Firestore clients.

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

Password-setup email requests are behind the `InvitationEmailSender`
abstraction. The MVP adapter calls Firebase Authentication's built-in
password-reset email endpoint, so Firebase sends its standard email and hosts
the default password-reset action handler. It has no Resend account, custom
sender domain, sender secret, or custom redirect URL. A later custom provider
can implement the same abstraction without changing the invitation domain or
Flutter UI.

The callable response contains only the invitation ID, normalized email,
pending status, invitation expiry, and `accepted` or `failed` email-request
status. `accepted` means Firebase Authentication accepted the request; it does
not claim inbox delivery or that the recipient opened the message.

An invitation is valid for seven days. Firebase password-reset action-code
expiry is managed by Firebase rather than by the Function; a failed email
request can be safely retried with the same invocation without creating
another Auth user, membership, or invitation. Firebase's default action-link
domain and handler are used for the MVP, without a `continueUrl`. The local
acceptance and activation path is implemented below; end-to-end representative
onboarding remains a separate, live-environment milestone.

## Invitation management workflow (local implementation)

The Team page separates existing members from pending invitations, preventing
the invited membership record from appearing as a duplicate team member. An
administrator can open an invite-by-email page, see whether Firebase accepted
or rejected the email request, retry a failed request, resend a pending
invitation, or revoke a pending invitation. The UI shows only email addresses
and human-readable states; it does not expose Firebase user IDs.

`resendWorkspaceInvitation` and `revokeWorkspaceInvitation` are trusted
callables. The backend first reserves an email-request attempt inside a
Firestore transaction. A pending request blocks concurrent callers, and the
backend applies a 60-second rate limit between attempts. Every accepted resend
asks Firebase Authentication to create a fresh password-reset action email,
while failures leave the same invitation, membership, Auth user, and audit
trail in place for a later retry.

Revocation is also transactional. It changes the invitation and its email lock
only when that specific invitation is pending. It changes a membership only
when the membership has the exact matching `invitationId` and is still
`invited`; an existing `active` representative is never revoked because of an
old invitation sharing their email address. Invitation expiry, email-request
state, and all audit fields remain backend-owned because Firestore client
writes are denied.

## Representative onboarding (local implementation)

The representative receives Firebase's hosted password-setup link through the
invitation email. After setting a password and signing in, their invited
membership directs them to **Activate your workspace**. The app sends only the
workspace and invitation IDs to `acceptWorkspaceInvitation`; the callable
derives the representative UID from Firebase Authentication.

Inside one Firestore transaction, the backend verifies that the invitation is
pending, unexpired, belongs to that exact UID, and matches the still-invited
sales membership and email lock. It then records acceptance audit fields,
marks the invitation and lock accepted, and activates that membership. Another
user cannot accept the invitation. An expired invitation is marked expired but
does not activate the membership.

`updateSalesRepresentativeStatus` is a separate no-secret callable for an
active administrator. It rechecks the acting admin and target representative
inside its transaction, applies only a permitted server-defined action, and
writes the status audit fields. Neither callable accepts a client-supplied role
or acting-user ID.

This is local implementation and emulator coverage only. Representative
onboarding is not complete until the deployed Function, Firebase-hosted
password setup, acceptance, activation, and first sales-representative session
are verified together in the development project. No billing change,
custom-sender configuration, email-provider secret, deployment, or live email
validation is included in this checkpoint.

### Deployment prerequisites

Do not deploy this Function until all of the following are complete for
`nexuscrm-dev-amitaswal` only:

1. Upgrade the development project to Blaze and add a Cloud Billing budget
   alert with agreed recipients and thresholds.
2. Create a dedicated non-secret API key for `nexuscrm-dev-amitaswal`, restrict
   it to the Identity Toolkit API, and configure it only as the
   `INVITATION_AUTH_WEB_API_KEY` Function parameter. It is not a Resend
   credential and must not be provided by the Flutter app or callable input.
3. Confirm Identity Toolkit quota usage is appropriate for development use. In
   Firebase Authentication, verify Email/Password sign-in is enabled and review
   the standard password-reset template and default hosted action handler.
4. Run `npm run test:functions`, `npm run test:firestore-rules`,
   `flutter analyze`, and `flutter test`.
5. After separate approval, deploy the Functions and manually test one
   development-only recipient through the Firebase-hosted password-reset,
   invitation-acceptance, and representative-activation flow. An accepted
   email request still must not be described as confirmed inbox delivery.

### Dependency advisory

As of 2026-07-13, `npm audit --omit=dev` reports nine moderate transitive
advisories in the Firebase Admin dependency tree. The available automated fix
would force a breaking downgrade of Firebase Admin, so it was not applied.
Re-run and review the production dependency audit before the first deployment.
