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
| 2. Navigation shell | Planned | Role-aware application navigation and feature destinations |
| 3. Sales dashboard | Planned | A useful sales home with staged data integration |
| 4. Lead and client management | Planned | Teams maintain customer records and ownership |
| 5. Tasks and follow-ups | Planned | Representatives organize actionable work |
| 6. Dialer and post-call notes | Planned | Representatives launch calls and record outcomes |
| 7. Admin user management and invitations | Planned | Administrators securely manage and invite representatives |
| 8. Sales-representative onboarding | Planned | Invited representatives establish accounts and enter the workspace |
| 9. Admin activity and basic reporting | Planned | Administrators review team activity and lightweight summaries |
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

## Planned MVP milestones

### 2. Navigation shell

Goal: replace placeholder destinations with a stable role-aware navigation
structure that later features can enter without repeatedly changing the
application shell.

Planned scope:

- Administrator and sales-representative navigation layouts
- Role-appropriate destinations and labels
- Nested routes that preserve authentication guards
- Shared page structure and consistent sign-out access
- Placeholder destinations for planned MVP features
- Navigation and widget tests

Definition of done:

- Authenticated administrators and representatives receive the correct
  navigation options.
- Users cannot enter routes outside their role.
- The shell works on supported Android and iOS screen sizes.
- Future features can replace placeholders without restructuring routing.

### 3. Sales dashboard

Goal: give sales representatives a clear starting point for daily work.

The dashboard is delivered before its supporting CRM datasets. Its first
version establishes layout, navigation, loading, and honest empty states.
Lead, task, and follow-up summaries are connected incrementally when those
features become available.

Planned scope:

- Sales-focused home layout
- Sections for today's follow-ups, overdue work, recent leads, and basic
  pipeline counts
- Useful empty and unavailable states without fabricated production data
- Quick navigation to available destinations
- Widget and routing tests

Definition of done:

- A representative reaches a polished sales home after authentication.
- Every dashboard section handles unavailable or empty data clearly.
- The layout is ready to receive real lead and task repositories later.

### 4. Lead and client management

Goal: establish the core CRM records and ownership workflow.

Planned scope:

- Typed lead and client models
- Workspace-scoped Firestore repositories
- Lead and client lists with loading, empty, and error states
- Create, view, edit, and archive flows
- Contact information and concise sales notes
- Lead ownership assignment to an active representative
- Basic lead status or pipeline stage
- Lead-to-client conversion
- Dashboard lead and pipeline integration
- Role-aware Firestore rules, indexes, and tests

Definition of done:

- Administrators and authorized representatives can manage records permitted by
  their role.
- Every record is isolated to its workspace.
- A lead can move through basic stages and convert into a client without losing
  relevant history.
- Dashboard lead summaries use real workspace data.

### 5. Tasks and follow-ups

Goal: turn CRM records into clear next actions.

Planned scope:

- Tasks linked to leads or clients
- Assignee, due date, status, and short notes
- Create, edit, complete, and reopen actions
- Today, upcoming, and overdue views
- Basic follow-up history
- Dashboard task and follow-up integration
- Role-aware access rules and tests

Advanced calendar views, reminders, and push notifications remain deferred.

Definition of done:

- A representative can identify and complete today's work.
- Administrators can review tasks within their workspace.
- Task updates remain linked to the relevant CRM record.
- Dashboard task summaries use real workspace data.

### 6. Dialer and post-call notes

Goal: support the common call-and-follow-up workflow without building a calling
service.

Planned scope:

- Launch the native phone dialer from a lead or client
- Return to Nexus CRM after the call
- Manually record call outcome, note, and next follow-up
- Store the activity against the CRM record and acting user

Automatic call detection or recording is not included.

Definition of done:

- A representative can initiate a call from a stored phone number.
- The app provides a clear manual post-call note flow.
- The resulting activity is visible on the related record.

### 7. Admin user management and invitations

Goal: let administrators manage their sales team and initiate secure
invitations without creating or viewing another user's password.

Planned scope:

- Administrator sales-representative list
- Backend-trusted invitation creation by email
- Invitation status
- Resend or revoke pending invitations
- Suspend and reactivate existing representatives
- Email delivery using Firebase-hosted password setup/reset for Version 1
- Updated Firestore rules, indexes, tests, and documentation

The backend implementation may require upgrading the Firebase project from the
Spark plan. Any billing change must be reviewed before implementation.

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

Planned scope:

- Invitation validation
- User-created password through Firebase's hosted flow
- Secure association between Firebase UID, invitation, and membership
- Membership activation
- Expired, revoked, invalid, and already-used invitation states
- First real sales-representative sign-in verification
- Android and iOS onboarding checks

Definition of done:

- An invited representative sets their own password.
- Exactly one active workspace membership is established.
- The representative signs in and reaches the sales dashboard.
- Invalid or revoked invitations cannot grant workspace access.

### 9. Admin activity and basic reporting

Goal: provide lightweight visibility into team work without building a detailed
analytics product.

Planned scope:

- Recent lead, task, and call-note activity
- Acting representative and timestamp
- Basic filtering by representative or activity type
- Lightweight counts useful to an administrator
- Workspace-scoped access and indexes

Definition of done:

- Administrators can review recent workspace activity.
- Representatives cannot access administrator-only views.
- Activity records are created consistently by relevant workflows.
- Summary queries are simple, indexed, and tested.

Detailed analytics and report generation remain deferred.

### 10. Final polish, testing, and release

Goal: prepare the portfolio project for a reliable demonstration.

Planned scope:

- Android and iOS end-to-end verification
- Accessibility and form-validation review
- Loading, offline, error, and empty-state review
- Firestore rules and index audit
- Dependency and lint review
- README, architecture, setup, and roadmap updates
- Release build verification

## Deferred work

The following items are intentionally outside the MVP:

- Workspace creation, selection, and switching
- Advanced calendar views
- Push notifications and reminders
- Document management
- WhatsApp and email integrations
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
