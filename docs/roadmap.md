# Nexus CRM project roadmap

## Product vision

Nexus CRM is a mobile-first CRM product for small sales teams. A customer
company uses its own private workspace inside the application. Administrators
manage the team and oversee activity, while sales representatives manage leads,
clients, tasks, calls, and follow-ups.

The MVP prioritizes a clear daily sales workflow over broad customization or
enterprise reporting.

## Product model

- Nexus CRM is the application.
- A workspace represents one customer company and contains its CRM data.
- A workspace membership connects a user to that company with an administrator
  or sales-representative role.
- Version 1 supports one active workspace per user and does not expose workspace
  selection or switching.
- The Firestore structure remains compatible with multiple customer workspaces
  in the future.

## Engineering principles

- Design each feature before implementation.
- Build one small, reviewable milestone at a time.
- Keep domain contracts independent of Flutter and Firebase where practical.
- Treat workspace membership and backend-trusted operations as security
  boundaries.
- Add dependencies only when they solve a current problem.
- Prefer explicit loading, empty, error, and access states.
- Test business rules and security-sensitive paths.
- Support Android and iOS; web is outside the project scope.
- Keep documentation synchronized at meaningful milestones.

## Delivery overview

| Milestone | Status | Outcome |
|---|---|---|
| Project foundation | Complete | Flutter shell, themes, linting, tests, and Git workflow |
| 1. Authentication foundation | Complete | Firebase sessions, membership resolution, role routing, rules, and indexes |
| 2. Navigation shell | Complete | Role-aware application navigation and feature destinations |
| 3. Sales dashboard | Complete | A useful sales home with staged data integration |
| 4. Lead and client management | Complete | Teams maintain customer records and ownership |
| 5. Tasks and follow-ups | Complete | Representatives organize actionable work |
| 6. Dialer and post-call notes | Complete | Representatives launch calls, log outcomes, and create follow-ups |
| 7. Admin user management and invitations | Complete | Administrators securely manage and invite representatives, deployed and verified live |
| 8. Sales-representative onboarding | Complete | Invited representatives establish accounts and enter the workspace, verified live on Android |
| 9. Admin activity and basic reporting | Complete | Administrators review team activity and lightweight summaries |
| 10. Final polish, testing, and release | Planned | Cross-platform quality and portfolio release readiness |

## Completed milestones

### Project foundation

Delivered:

- Android and iOS Flutter project
- Nexus CRM application shell
- Shared Material 3 light and dark themes
- Lint configuration and smoke test
- `main`, `dev`, and focused feature-branch workflow

### 1. Authentication foundation

Delivered:

- Firebase development project configuration
- Email/password sign-in and sign-out
- Restored Firebase sessions
- Typed authentication and workspace-membership domain contracts
- Firebase Authentication and Firestore repository adapters
- Single-active-membership enforcement
- Administrator and sales-representative role routing
- Explicit invited, suspended, revoked, missing, failed, and misconfigured
  session states
- Firestore default-deny rules and required collection-group indexes
- Repository, state-management, routing, widget, and Firestore rules tests
- Manually seeded development administrator

See [Authentication architecture](authentication.md) for implementation
details and security decisions.

### 2. Navigation shell

Delivered:

- Shared Home, Leads, Tasks, and More destinations
- Role-prefixed administrator and sales route trees
- Bottom navigation on phones and navigation rail on wider screens
- Indexed-stack branches that preserve tab state
- Authentication guards and cross-role route protection
- `/admin` and `/sales` redirects to role-specific home routes
- Sign-out placement inside More
- Placeholder destinations for planned MVP features
- Phone, wide-layout, redirect, role, tab, and sign-out widget tests

See [Navigation shell](navigation.md) for the route map and integration rules.

### 3. Sales dashboard

Delivered:

- Authenticated display-name greeting with email fallback
- Leads and Tasks quick actions
- Real lead and client overview counts
- Pipeline-stage summary and recent-contact navigation
- Honest unavailable task and follow-up states without fabricated data
- Responsive phone, medium, and wide layouts
- Widget, identity-fallback, quick-action, layout, and routing tests

Lead, client, pipeline, and recent-contact summaries now use real contact data.
Task and follow-up summaries remain unavailable until their milestone.

See [Sales dashboard](sales-dashboard.md) for presentation and integration
details.

### 4. Lead and client management

Delivered:

- One stable contact record across the lead-to-client lifecycle
- Workspace-scoped Firestore contact persistence
- Administrator workspace access and sales ownership isolation
- Lead/client lists with local type filters
- Lead creation with role-aware assignment
- Read-only contact details and lead/client editing
- Basic lead stages and atomic lead-to-client conversion
- Soft archive without destructive deletion
- Active sales-assignee directory for administrator assignment
- Real sales-dashboard counts, pipeline stages, and recent contacts
- Firestore rules, indexes, emulator tests, Cubit tests, and widget tests

See [Lead and client management](lead-management.md) for implementation and
security details.

### 5. Tasks and follow-ups

Delivered role-scoped task lists, calendar due dates, task lifecycle actions,
contact links, dashboard metrics, and verified Firestore rules.

See [Task cancellation](task-cancellation.md) for the task state machine, which
milestone 10 extended with a cancelled status.

### 6. Dialer and post-call notes

Delivered native dialer launch, append-only call notes, optional atomic
follow-up creation, and compact/dedicated contact activity timelines.

See [Dialer, call notes, and follow-ups](dialer-post-call-notes.md) for the
workflow, schema, permissions, and routes.

## Planned MVP milestones

### 7. Admin user management and invitations

Goal: let administrators manage their sales team and initiate secure
invitations without creating or viewing another user's password.

Checkpoints 1 and 2 are complete: lifecycle states, audit fields,
backend-owned invitation semantics, default-deny client writes, indexes,
emulator coverage, and the administrator team directory are in place.
Checkpoint 3A and 3B are complete locally: the trusted callable backend,
provider abstraction, invite-management UI, safe resend/revoke controls, and
separate pending-invitation directory are in place. The final local code
checkpoint adds representative invitation acceptance/activation and
administrator suspend, reactivate, and revoke controls for sales
representatives. Local manual UI/UX reviews are complete.

The Functions, Firestore rules, and indexes were deployed to
`nexuscrm-dev-amitaswal` on 2026-07-25 after the Blaze upgrade and budget
alert. An administrator invited a real development-only recipient, Firebase
delivered the password-setup email, and the invitation moved from pending to an
active representative in the team directory. An Artifact Registry cleanup
policy limits deployment image retention to one day.

The first deployment used an API key created under a different Firebase
project. Because email enumeration protection returns success without sending
for an unknown address, the invitation reported an accepted email request while
no message was ever sent. The deployment prerequisites now require verifying
that the configured key resolves to the intended project.

Planned scope:

- Administrator sales-representative list
- Backend-trusted invitation creation by email
- Invitation status
- Resend or revoke pending invitations
- Suspend and reactivate existing representatives
- Email delivery using Firebase-hosted password setup/reset for Version 1
- Updated Firestore rules, indexes, tests, and documentation

Deploying the backend requires upgrading the Firebase development project from
the Spark plan. Any billing change must be reviewed before deployment.

Not included:

- Branded deep links
- Administrator-created passwords
- Bulk imports
- Multiple-workspace invitations

Definition of done:

- An administrator can invite a representative by email and see the invitation
  state.
- Administrators never create, receive, or view representative passwords.
- Revoked or suspended representatives cannot access workspace data.
- Invitation and membership-management writes are backend-trusted and tested.

### 8. Sales-representative onboarding

Goal: allow an invited representative to establish their own credentials and
enter the correct workspace.

Backend acceptance and activation landed with the admin-management branch; the
representative-facing activation experience, its routing guarantees, and its
documentation landed on the onboarding branch.

The milestone was verified live on 2026-07-25. An administrator invited a
representative from the iOS simulator, the representative received Firebase's
password-setup email, set their own password, signed in on an Android device,
reached the activation screen because their membership was still invited,
activated the workspace, and landed on the sales dashboard. The administrator's
team directory then showed the same account as an active sales representative
rather than a pending invitation.

Delivered scope:

- Invitation validation and single-use acceptance
- User-created password through Firebase's hosted flow
- Secure association between Firebase UID, invitation, and membership
- Transactional membership activation
- Expired, revoked, invalid, and already-used invitation states
- Activation screen with explicit ready, in-flight, activated, recoverable,
  and terminal states
- Retry limited to transient availability failures, with sign-out recovery for
  every other outcome
- Session-driven redirect into the sales workspace after activation
- Activation, routing, session, and emulator coverage for the acceptance and
  membership-transition paths

Definition of done, all met:

- An invited representative sets their own password.
- Exactly one active workspace membership is established.
- The representative signs in and reaches the sales dashboard.
- Invalid or revoked invitations cannot grant workspace access.

The first three were verified live. The fourth is covered by emulator tests for
replay, expiry, revocation, and wrong-account acceptance rather than by a live
attempt, because provoking those states against the development project would
consume real invitations without adding confidence.

Live verification also exposed a defect that shipped with the invitation flow.
The backend created memberships without a `displayName`, while the
sales-assignee mapper required one, so activating the first invited
representative left every administrator screen that assigns work stuck loading.
Representatives now supply their name during activation, readers fall back to
the email address instead of failing, and one unreadable membership can no
longer empty or stall a directory.

Follow-up work, carried into a later milestone:

- Representative activation was exercised on Android only. The iOS simulator
  covered the administrator invitation path.
- Memberships activated before display-name capture existed still show an email
  address wherever a name is expected.

### 9. Admin activity and basic reporting

Goal: provide lightweight visibility into team work without building a detailed
analytics product.

Activity is recorded as it happens rather than reconstructed later. The
`activities` collection already carries a `type` field and append-only rules
for call notes, so the same collection gains the remaining event types. A
derived feed was rejected because a contact's `updatedAt` records that
something changed without recording what changed or who changed it.

Recorded events:

- A lead is created
- A lead is converted to a client
- A task is completed
- A call note is logged, which already exists

Task creation is deliberately not recorded, because planning a week of work
would bury the events worth reading. Contact archiving is also not recorded.

Planned scope:

- Workspace activity feed on the administrator home, replacing its placeholder
- Acting representative and timestamp on every entry
- Filtering by representative and by activity type
- Counts of new leads, new clients, calls logged, and tasks completed
- A period selector covering the last 7 days, 30 days, year, and all time,
  defaulting to 7 days and shared by the counts and the feed
- Workspace-scoped access, rules for each new event type, and indexes

Each event is written in the same batch as the change that caused it, so the
feed cannot drift from the records it describes. Events are append-only and
carry the acting user, which rules verify against the caller.

Definition of done, all met:

- Administrators can review recent workspace activity.
- Representatives cannot access administrator-only views.
- Activity records are created consistently by relevant workflows.
- Summary queries are simple, indexed, and tested.

Rules and indexes were deployed to `nexuscrm-dev-amitaswal` on 2026-07-26, and
the feed, counts, filters, and period selector were verified live on the iOS
simulator against activity generated from an Android device.

Two defects surfaced during that verification. Actor names originally resolved
from the sales-assignee directory, which excludes administrators, so an
administrator's own work was attributed to a former representative. Separately,
task rules required an active sales representative as the assignee, which made
the tasks that revocation moves to an administrator impossible to edit or
complete; the emulator tests had not caught it because the Admin SDK bypasses
rules.

The feed begins empty, because work completed before this milestone was never
recorded. Backfilling historical activity is out of scope.

Detailed analytics and report generation remain deferred.

See [Admin activity and basic reporting](admin-activity.md) for the recorded
events, write ordering, and access model.

### 10. Final polish, testing, and release

Goal: prepare the portfolio project for a reliable demonstration.

Planned scope:

- Android and iOS end-to-end verification
- Accessibility and form-validation review
- Loading, offline, error, and empty-state review
- Firestore rules and index audit
- Dependency and lint review — **done**
- Document sharing — **done**, added to version 1 scope during this milestone
- README, architecture, setup, and roadmap updates
- Release build verification

Known gaps to close:

- **Task cancellation. Closed.** A task could be created, edited, and
  completed, but never removed, so an administrator who inherited open tasks
  from a revoked representative had no way to clear ones that no longer
  mattered. This was first specified as a soft archive mirroring contacts, and
  that framing was wrong. Archiving answers "hide this from my lists"; a task
  already has a terminal state for work that was done. The real need is a way
  to record that work will never be done, which is cancellation. A third
  `TaskStatus` value costs no new field, no backfill, and no index, because
  every task document already carries `status`, and it makes restore fall out
  of the existing reopen path rather than needing a second new action. See
  `docs/task-cancellation.md`.

Carried forward from this milestone's work:

- **Tasks stranded with a revoked representative. Closed.** Every write to a
  task was validated against an active assignee, so a completed task left with a
  revoked representative could not be touched at all. An administrator may now
  complete or cancel such a task without changing its assignee. Reopening still
  requires reassigning it to an active member first, because an open task held
  by someone who cannot act on it is the problem being solved. See
  `docs/task-cancellation.md`.
- Archiving a contact does not cascade to its tasks. The archive confirmation
  now reports the open-task count so the choice is informed, and those tasks
  can be cancelled individually. An automatic cascade was rejected: a
  representative archiving a contact whose follow-up is assigned to an
  administrator would fail the rules check and abort the whole batch.
- **Contact restore. Closed.** Contacts could be archived but never restored,
  the same asymmetry that was rejected for tasks. An **Archived contacts**
  screen now lists them with a Restore action, reachable from the overflow menu
  on the leads list. Archived contacts stay uneditable until restored, which is
  deliberately stricter than cancelled tasks: a task is a work item worth
  correcting in place, an archived contact is a record being kept out of the
  way. See `docs/lead-management.md`.
- The Completed and Cancelled task views load every matching document with no
  limit or date window. Harmless at demo scale; a date filter or page size is
  the fix if the workspace grows.
- **`engines.node` pinned to 22. Closed, and not a defect.** That pin is the
  Cloud Functions deploy runtime, not the local toolchain, and a deploy on
  2026-07-29 confirmed it running as `Node.js 22 (2nd Gen)`. `@types/node` is
  pinned to the same major so the types describe the runtime that actually
  serves requests. A local Node 26 only compiles TypeScript and drives the
  emulator, so the two versions are not in conflict.

- **Document sharing. Added to version 1.** The follow-up loop ended at
  scheduling the next action: a representative could record that a client wanted
  a quote but had no way to send one. Attaching files from the device was
  rejected because it puts uncontrolled, unapproved, unrevocable documents in
  front of clients, and because a share sheet needs the file on the phone
  anyway. Documents are published centrally by an administrator and shared as
  expiring, revocable links. See `docs/document-sharing.md`.

  Verified on device: an administrator can publish, and a representative can
  send by both WhatsApp and email. Three defects were found only by running it,
  and all three are fixed. Publishing failed because the app asked for an ID
  token with `getIdToken()`, got nothing back from a long-lived session, and
  reported the empty token as a permission error; see
  `docs/document-upload-postmortem.md`. The share screen then failed for
  representatives because a read rule that inspects `resource.data` is checked
  against the query rather than each result, so the query has to carry the
  filter the rule depends on. It also failed for both roles because three
  composite indexes were missing. Neither of the last two can be caught by the
  test suites: the emulator does not enforce indexes, and the rules half was
  only provable once a test issued the same query the client does.

Findings from the dependency and lint review, none of them blocking:

- **Two dependency advisories cannot currently be fixed.** `fast-xml-parser`
  (high) and `uuid` (moderate) both arrive transitively through
  `firebase-admin`. Upgrading `firebase-admin` from 13 to 14 was measured and
  makes matters worse — 13 advisories with 6 high, against 10 with 1 high — so
  it was reverted. The `uuid` issue only applies when passing a caller-supplied
  buffer to v3, v5, or v6, which nothing here does. `fast-xml-parser` arrives
  through `@google-cloud/storage`, which **this project now does use** — the
  review predated document sharing, and `publishDocument` writes to the bucket
  through the Admin SDK. The parser handles responses from Google's own storage
  endpoint rather than anything a caller supplies, so the exposure is
  indirect, but the earlier claim that the package is unreachable no longer
  holds and should be re-checked. Re-test the upgrade when `firebase-admin` 14
  settles.
- **The emulator does not run the production Node version.** Cloud Functions
  serve on Node 22 while the emulator runs under whatever Node is installed
  locally, currently 26. The twenty emulator tests therefore exercise a
  different major version than production. The fix is to run the emulator under
  Node 22, not to move the deploy target.
- **The Functions package has no linter.** There is no ESLint configuration and
  no lint script; the TypeScript compiler is the only static check. Adding one
  now would surface a backlog immediately before a release, so it is recorded
  rather than opened.
- **`typescript` 5 to 7 and `@types/node` 22 to 26 were skipped deliberately.**
  The first is a major toolchain jump with no benefit to this project; the
  second would describe a Node version the functions do not run on.

## Open design questions

Unlike deferred work, these are not decisions that have been made and postponed.
They are decisions that have not been made at all, and they should be resolved
before a version 1 release.

### Reassignment has no handover

A task can be moved from one person to another silently and unilaterally. The
permissions allow it deliberately — an administrator has authority over all
workspace tasks, and any administrator may take a task another administrator
holds — but the *interaction* around it was never designed.

Nobody is told when work leaves them. A representative who has been calling a
lead for a week can lose that task without notice, and has no way to pass on
what they learned or what they had planned. The same happens between
administrators: one may have a considered approach to a contact, and another can
take the task away without a word being exchanged. Work already invested becomes
invisible, and the person picking the task up starts from nothing.

The gap is communication, not permission. Restricting who may reassign would not
fix it; two people still need to agree on a handover. Directions worth weighing,
none of them chosen:

- Record reassignment as a workspace activity event, so it is at least visible.
  Weigh this against the milestone 9 decision to keep the feed short and
  readable.
- Require a handover note when reassigning, and show it to the new assignee.
- Notify the previous assignee rather than letting the task vanish.
- Make a transfer an offer that the receiving person accepts, instead of a write
  that lands on them.

This also interacts with revocation, which reassigns a representative's open
work automatically. That transfer is justified — the person is gone — but it is
equally silent, and whatever is decided here should cover it.

## Deferred work

The following items are intentionally outside the MVP:

- Workspace creation, selection, and switching
- Advanced calendar views
- Push notifications and reminders
- Rich document management: folders, versioning, previews, and per-contact
  access lists. Basic publishing and sharing shipped in milestone 10; see
  `docs/document-sharing.md`.
- Deeper WhatsApp and email integration. Sharing hands a link to the device's
  WhatsApp or email application; the product does not send messages itself and
  has no WhatsApp Business API relationship.
- Detailed reports and analytics
- Branded authentication deep links
- Automatic call tracking or recording
- Web support

## Common definition of done

A feature milestone is complete when:

- Its agreed scope is implemented without unrelated work.
- Business logic, routing, and security-sensitive behavior have proportionate
  tests.
- `flutter analyze` and relevant tests pass.
- Android and iOS risk is checked in proportion to the change.
- Firestore rules and indexes are reviewed and deployed when required.
- User-facing flows are manually verified where practical.
- Documentation reflects meaningful architecture or setup changes.
- Changes are reviewed before commit.
- The completed feature branch is merged into `dev` and deleted.

## Delivery workflow

- `main` contains stable, release-ready work.
- `dev` integrates completed feature branches.
- Each feature branch starts from `dev`.
- Design is discussed before code is written.
- Commits represent meaningful, reviewable checkpoints.
- No commit is created until the changes are reviewed and approved.
- After a feature is complete, its branch is merged into `dev`, deleted, and a
  new feature branch is created only after its scope is confirmed.

This roadmap records the current direction. Scope or ordering can change when
new product information justifies it, but changes should be discussed and
documented before implementation.
