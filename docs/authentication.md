# Authentication architecture

## Product, workspace, and membership

Nexus CRM is the application. A workspace is one customer company's private
area inside the application, containing that company's users and CRM data. For
example, `Northstar Solutions` can be a workspace inside Nexus CRM.

A workspace membership connects one Firebase user to one workspace. It stores
the user's role and access status. An active membership means the user may
currently enter that workspace.

One workspace can contain many users. Version 1 allows each user to have only
one active workspace membership because workspace selection is not yet part of
the product.

## Scope

The authentication foundation provides email/password sign-in, Firebase
session restoration, Firestore membership resolution, and role-based routing
for administrators and sales representatives.

Version 1 assumes exactly one workspace membership per authenticated user. The
Firestore model remains compatible with multiple workspaces, but workspace
selection and switching are not implemented. More than one active membership
is treated as a configuration error.

Sales-representative invitations, Cloud Functions, email delivery, password
setup links, and administrator user-management screens are deferred.

## Session flow

1. Firebase Authentication restores or emits the current user.
2. `SessionBloc` observes the authentication stream.
3. For an authenticated user, the membership repository queries every
   `members` subcollection for documents whose `userId` matches the Firebase
   UID.
4. `SessionBloc` resolves membership status and validates the single-workspace
   invariant.
5. `go_router` sends an active administrator to `/admin` and an active sales
   representative to `/sales`.
6. Invited, suspended, revoked, missing, failed, and misconfigured sessions
   have explicit destinations.

Membership events are generation-tagged so results from a previous user are
ignored after authentication changes. Authentication and membership
subscriptions are cancelled when replaced and when the bloc closes.

## Layers

The domain layer contains Flutter- and Firebase-independent entities, typed
failures, and repository contracts:

- `AuthUser`
- `WorkspaceMembership`
- `AuthSession`
- `AuthenticationFailure`
- `AuthenticationRepository`
- `MembershipRepository`

The data layer adapts Firebase Authentication and Cloud Firestore to those
contracts. Firebase exceptions and malformed documents are converted to typed
domain failures.

The presentation layer contains:

- `SessionBloc` for application-wide session orchestration
- `SignInCubit` for sign-in submission state
- Session and sign-in pages
- Router guards and role destinations

## Firestore model

```text
users/{uid}
workspaces/{workspaceId}
workspaces/{workspaceId}/members/{uid}
```

A membership document requires these string fields:

```text
workspaceId: <parent workspace document ID>
userId:      <membership document ID and Firebase Auth UID>
role:        admin | sales_rep
status:      invited | active | suspended | revoked
```

The mapper rejects missing fields, unsupported values, invalid collection
paths, and ID mismatches.

## Authorization and indexing

Firestore rules use default-deny access:

- Authenticated users may read only their own profile.
- Authenticated users may query only memberships whose `userId` equals their
  Firebase UID.
- Client profile and membership writes are denied.
- Workspace and all unspecified data remain denied.

Trusted backend logic will own membership writes when invitations are
implemented.

The membership lookup uses:

```text
collectionGroup("members").where("userId", isEqualTo: uid)
```

Cloud Firestore therefore requires ascending and descending collection-group
indexes for `members.userId`. The configuration is stored in
`firestore.indexes.json`.

## Development seeding

Development administrators are seeded manually in Firebase Console until the
invitation backend exists:

1. Create an email/password Firebase Authentication user.
2. Copy the generated UID.
3. Create `users/{uid}` with the user's email and display name.
4. Create the workspace document if it does not exist.
5. Create `workspaces/{workspaceId}/members/{uid}` with matching IDs,
   `role: admin`, and `status: active`.

Passwords must remain private and must never be stored in Firestore,
documentation, source control, or administrator-facing screens.

## Testing

Flutter tests cover:

- Firebase Authentication mapping and typed failures
- Firestore membership mapping, sorting, and failures
- Session status resolution and configuration errors
- Stale event handling and subscription cleanup
- Sign-in submission behavior
- Administrator and sales-representative routing
- Cross-role route protection

Firebase Emulator tests cover unauthenticated access, self-profile reads,
self-membership collection-group queries, cross-user denial, and denied client
writes.

The development administrator flow has been verified on iOS for sign-in,
session restoration, role routing, sign-out, and reauthentication. A real
sales-representative onboarding test is deferred until the invitation feature;
sales routing is currently covered by automated tests.

## Planned onboarding

The administrator will invite a sales representative by email. Backend-trusted
logic will create and update invitation and membership records. The
representative will set their own password through Firebase's hosted password
setup/reset flow. Administrators will never create, receive, or view another
user's password.

Branded deep links, workspace selection, workspace switching, and custom-claim
workspace roles remain out of scope for Version 1.
