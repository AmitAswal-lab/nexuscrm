# Admin activity and basic reporting

The administrator home answers one question: what has the team been doing?
It is a glance rather than a report. Detailed analytics remain deferred.

## Recorded events

Activity is recorded as it happens rather than reconstructed later. Each event
is one document in `activities`, the collection that already held call notes,
distinguished by its `type` field.

| Event | Recorded when |
|---|---|
| `lead_created` | A lead is created |
| `lead_converted` | A lead becomes a client |
| `task_completed` | A task is completed |
| `call_note` | A call is logged, which predates this milestone |

Task creation is deliberately not recorded, because planning a week of work
would bury the events worth reading. Contact archiving is not recorded either.

A derived feed was rejected. A contact's `updatedAt` records that something
changed without recording what changed or who changed it, so the resulting
timeline could never say "Priya converted Acme Corp".

## Writing an event

Every event is written in the same batch or transaction as the change that
caused it, so the feed cannot drift from the records it describes. Lead
creation uses a batch; conversion and task completion already ran in
transactions and now write the event inside them.

Events store the contact's name alongside its ID. The feed therefore renders
without reading a contact per row, and a record keeps the name the contact had
at the time. Task events additionally store the task ID and title.

Task completion reads its contact inside the transaction to capture that name.
If the contact cannot be read, the task still completes and the event is
skipped, because completing work matters more than recording it.

## Reading the feed

`watchWorkspaceActivity` orders by `createdAt` descending and accepts an
optional period, representative, and type. Documents that cannot be mapped are
skipped rather than failing the stream, so one malformed record cannot empty
the screen.

The administrator home shows the four counts and a period selector. Each count
opens the feed filtered to that type, carrying the chosen period across. The
feed screen adds the representative and type filters.

Counts reflect the active filters rather than the whole workspace. On the home
screen no representative or type filter exists, so they are workspace-wide
there.

## Names

Actor names resolve from the team directory, not the sales-assignee directory,
because administrators act too and never appear in the latter. Only active
members are offered as filter options: a workspace accumulates one membership
per invitation, so a returning representative would otherwise appear several
times, once per identity.

A departed member's past activity still shows in the feed, attributed to
`Former representative` because their name is no longer resolvable.

## Access

Administrators read all workspace activity. A representative reads only
activity for contacts they own, which the existing `canReadActivity` rule
already enforced. Events are append-only, validated per type, and carry an
actor that rules verify against the caller, so a representative cannot record
work in someone else's name.

Two indexes support the filters: `actorUserId` with `createdAt`, and `type`
with `createdAt`. The unfiltered feed needs no composite index.

## Task assignees

Revoking a representative moves their open tasks to the revoking administrator.
That required widening task rules, which previously demanded an active sales
representative as the assignee, to accept an active administrator as well.
Without it those tasks could not be edited or completed by anyone. Contact
ownership is unchanged and still belongs to sales representatives only.

## Remaining work

The feed begins empty. Work completed before this milestone was never
recorded, and backfilling historical activity is out of scope.
