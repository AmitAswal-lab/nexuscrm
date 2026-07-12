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
