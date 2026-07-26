# Sales-representative onboarding

This document covers the representative-facing side of onboarding: how an
invited user reaches workspace activation, what the activation screen
guarantees, and how failures are presented. The backend invitation and
membership semantics are documented in
[Admin user management](admin-user-management.md).

## Onboarding journey

1. An administrator invites a representative by email. The backend creates a
   Firebase Authentication user with a server-generated password that is never
   returned, creates the invited membership in the same transaction, and asks
   Firebase Authentication to send its standard password-setup email.
2. The representative sets their own password through Firebase's hosted action
   handler. The application is never involved in choosing, transmitting, or
   storing that password.
3. The representative signs in with the invited email address.
4. `SessionBloc` resolves one `invited` membership and no active membership, so
   the router sends them to workspace activation instead of a role home.
5. The representative activates the invitation. The backend transactionally
   accepts it and flips the membership to `active`.
6. The membership stream emits the activated record, `SessionBloc` becomes
   `SessionAuthenticated`, and the router redirects to `/sales/home`.

Steps 1 and 2 depend on deployed Functions and real email delivery. Steps 3
through 6 are implemented and covered by automated tests.

## Activation route

`SessionInvitationPending` is the only state that routes to
`/invitation-pending`. The route builder falls back to the loading page if the
session is in any other state, so the activation screen can never render
without an invited membership behind it.

## Display name

Activation is where a representative supplies the name their team sees. The
name is required, trimmed, collapsed to single spaces, and limited to eighty
characters by the callable, which writes it onto the membership inside the same
transaction that activates it. Client writes to membership documents are
denied, so this is the only path by which a representative can name themselves.

The name lives on the membership rather than the Firebase Authentication
profile because the membership stream is already live: the greeting, the team
directory, and the sales-assignee directory all update the moment activation
commits. An Authentication profile change would not reach the app until the
next token refresh.

A membership created before this field existed, or by any other path, has no
display name. Readers fall back to the email address rather than failing, so a
directory can never be emptied by one incomplete record.

## Activation behaviour

Activation never navigates by itself. The page reports success and waits; the
redirect is driven entirely by the session stream once the backend has
activated the membership. This keeps one source of truth for routing and means
a failed or partial activation cannot strand the user inside the sales shell.

A user with more than one invited membership resolves to
`SessionConfigurationError` rather than activation, preserving the
single-workspace invariant.

`NexusCrmApp` accepts an optional `invitationRepository`, which `AppRouter`
passes to the activation page. Production leaves it unset and the page builds a
`FirebaseCallableInvitationRepository` over `FirebaseFunctions.instance`; tests
inject a fake so the whole route can be exercised without Firebase.

## Activation screen states

| State | What the representative sees |
|---|---|
| Ready | An explanation, a reminder to use the invited email address, a required **Your name** field, and **Activate workspace** |
| In flight | A spinner with **Activating workspace…**; both activation and sign-out are disabled |
| Activated | A confirmation that the workspace is opening; the action is removed so it cannot be submitted twice |
| Recoverable failure | The reason, plus **Try again** |
| Terminal failure | The reason, a disabled **Activation unavailable**, and sign-out recovery |
| Missing invitation reference | Guidance to sign out and sign in again |

Sign-out is always available except while a request is in flight or after
activation has succeeded, so a representative who signed in with the wrong
account can recover without help.

## Failure handling

Callable errors are mapped to a typed `InvitationActionFailure` in the data
layer, so the presentation layer never inspects Firebase error codes.

| Callable code | Failure code | Retryable |
|---|---|---|
| `unavailable`, `deadline-exceeded` | `unavailable` | Yes |
| `failed-precondition` | `expired` | No |
| `permission-denied`, `unauthenticated` | `accessDenied` | No |
| `invalid-argument` | `invalidInput` | No |
| anything else, or a non-callable error | `unknown` | No |

Only `unavailable` offers a retry, because only a transport or availability
problem can succeed on a second identical attempt. Every other outcome reflects
backend state that the representative cannot change by pressing the button
again: an expired, revoked, or already-accepted invitation, or an invitation
belonging to another account. Those messages point at the real remedy, which is
to ask an administrator for a new invitation or to sign in as the invited
account.

Unexpected exceptions are caught and presented as the generic terminal failure
rather than surfacing a raw error, so activation cannot leave the screen stuck
in its in-flight state.

## Security properties

The client sends only a workspace ID and an invitation ID. The acting user is
derived from Firebase Authentication inside the callable, so a representative
cannot activate someone else's invitation by editing a request. Acceptance is
single-use and transactional, and an expired invitation is marked expired
without granting access. Client writes to membership and invitation documents
remain denied by Firestore rules.

## Test coverage

- Activation screen: in-flight state, successful activation, retry after a
  transient failure, a non-retryable expired invitation, an unexpected error,
  and sign-out recovery.
- Routing: an invited representative reaches activation, and a session that is
  not invitation-pending does not.
- Session: an invited representative transitions into the sales workspace once
  the membership becomes active.
- Emulator: acceptance by the matching user only, expiry without activation,
  single-use replay rejection, refusal to activate a revoked invitation, and
  the permitted membership status transitions.

## Live verification

Verified against `nexuscrm-dev-amitaswal` on 2026-07-25. An administrator
invited a development-only recipient from the iOS simulator, Firebase delivered
the password-setup email, and the representative set their own password, signed
in on an Android device, reached the activation screen, activated the
workspace, and landed on the sales dashboard. The administrator's team
directory then listed the account as an active sales representative.

Two things are worth recording from that run. Firebase accepting an email
request is still not evidence of inbox delivery: the first attempt reported an
accepted request and delivered nothing, because the configured API key belonged
to a different Firebase project and email enumeration protection returns
success for an unknown address. Deployment now verifies the key's project
first, as described in [Admin user management](admin-user-management.md).

## Remaining work

- Representative activation has been exercised on Android only.
- Memberships activated before display-name capture existed still show an email
  address wherever a name is expected.
