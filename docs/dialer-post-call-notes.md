# Dialer, call notes, and follow-ups

## Workflow

Nexus CRM launches the device's native phone dialer from a contact detail page.
Calls are logged manually after the user returns; automatic call detection and
recording are outside the MVP.

1. Select **Call contact** to launch a validated `tel:` URI.
2. Select **Log call note**, choose an outcome, and optionally add a note.
3. Optionally create a follow-up with a title, calendar date, and assignee.
   Sales representatives are assigned to themselves; administrators select an
   active representative.

## Activity model and security

Call notes are stored at:

```text
workspaces/{workspaceId}/activities/{activityId}
```

```text
workspaceId
type                    call_note
contactId
outcome                 connected | voicemail | no_answer | wrong_number | other
note                    nullable
actorUserId
createdAt
nextTaskId              nullable
```

Activities are append-only. Administrators may access workspace activity;
sales representatives may access activity only for contacts they own. The
actor must be the authenticated user.

When `nextTaskId` is present, rules require it to refer to a newly-created,
open follow-up for the same contact in the same atomic write. The activities
query uses a `contactId` ascending, `createdAt` descending composite index.

## Activity views

Contact details show a three-entry **Recent activity** preview. **View all
activity** opens a reverse-chronological timeline of call notes and follow-up
tasks. Administrator views resolve active sales-representative names and never
show raw identifiers.

## Routes

```text
/admin/leads/:contactId/call-note
/admin/leads/:contactId/activity
/sales/leads/:contactId/call-note
/sales/leads/:contactId/activity
```

## Verification

```sh
flutter analyze
flutter test
npm run test:firestore-rules
```
