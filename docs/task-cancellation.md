# Task cancellation

A task can now be cancelled and reopened. Cancellation records that work will
never be done, which is different from recording that it was done.

## Why not an archive

The gap was first written up as a soft archive, mirroring contacts. That was
the wrong shape for a task, for three reasons.

A contact is archived to get it out of the way; it has no natural end. A task
already has a terminal state. What was missing was not "hide this" but "this
will never happen" — an administrator inheriting open tasks from a revoked
representative cannot complete them, because the work did not happen and
completing writes a `task_completed` event asserting that it did.

An archive also needs an `isArchived` field that no existing task document
carries, which means either a backfill or permanent tolerance for its absence
in both the mapper and the rules. Every task already carries `status`, so a
third value costs nothing to migrate.

Finally, an archive that cannot be undone is a trap, and contacts already have
that defect. Reopen already exists for completed tasks; widening it to accept a
cancelled task makes restore nearly free rather than a second new action.

## State machine

| From | To | Allowed |
|---|---|---|
| `open` | `completed` | Yes, unchanged |
| `open` | `cancelled` | Yes |
| `completed` | `open` | Yes, unchanged |
| `cancelled` | `open` | Yes |
| `completed` | `cancelled` | No |
| `cancelled` | `completed` | No |

`completed` to `cancelled` is denied because the work genuinely happened and
its activity event is already written; cancelling would contradict the record.
`cancelled` to `completed` is denied so that each transition is a separate,
auditable write — reopen first, then complete.

Nothing is destroyed. Client deletes stay denied everywhere.

## Where cancelled tasks go

Cancelling never removes history, so a cancelled task remains readable.

- The Today, Upcoming, and Overdue views, and the sales dashboard's due-today
  and overdue counts, show open tasks only.
- A fifth Cancelled view on the task list holds them, and opening one offers
  Reopen.
- A contact's activity timeline still lists cancelled follow-ups, labelled
  `Cancelled`. The timeline is a history, and deciding not to do something is
  part of that history. It is also the path back to a follow-up someone wants
  to revive.

Those filters previously read `!task.isCompleted` as a synonym for open. A
third state makes that a bug, so `CrmTask` exposes `isOpen` and every filter
uses it.

## Completion history survives

A task can be completed, reopened, and then cancelled. `completionCount` and
the last-completion metadata are preserved through cancellation, so the rules
treat `cancelled` with the same metadata shape already permitted for `open`:
either no completions and no metadata, or a positive count with metadata.
`isTaskCancellation` allows only `status`, `updatedByUserId`, and `updatedAt`
to change, so a cancellation cannot rewrite what happened.

Content edits are unaffected. `isTaskContentUpdate` already requires the status
to be unchanged, so it cannot smuggle a transition, and a cancelled task can be
edited on the same terms as a completed one.

Creation still pins `status` to `open`. A task cannot be born cancelled.

## Revoking a representative

`releaseRepresentativeWork` moves a revoked representative's tasks to the
acting administrator. It previously moved open tasks only, on the reasoning
that completed work should stay with whoever did it.

Cancelled tasks must move too. `hasValidTaskData` requires an active assignee,
so a cancelled task left with a revoked user could never be reopened, which
would put a hole in the restore path that justifies cancellation in the first
place.

Completed tasks still stay with the person who completed them, so the record of
who did the work survives revocation.

## Tasks left with an inactive member

A task whose assignee is no longer active used to be frozen. Every write was
validated against an active assignee, so an administrator inheriting one could
neither close it nor clear it.

The assignee check now runs in two places rather than one. Creating a task still
requires an active assignee. Updating a task requires an active assignee too,
with a single exception: an administrator may complete or cancel a task while
leaving its assignee exactly as it is.

Reopening is deliberately excluded. Reopening restores the task to the active
lists, and an open task held by someone who cannot act on it is the problem this
exception exists to solve. To reopen one, reassign it to an active member first
and then reopen it — reassignment already worked, because the check has always
validated the incoming assignee rather than the stored one.

Handing a task to an inactive member remains impossible in every direction.

## Who can hold a task

A task may be assigned to any active sales representative, or to the
administrator making the assignment. The assignee picker shows **Me** followed
by the active representatives.

An administrator cannot assign work to a *different* administrator. Delegation
runs downward to representatives, or an administrator takes the task
themselves; passing it sideways between administrators is not a workflow this
product has, and allowing it would create tasks that nobody is accountable for.

A second administrator can still edit, complete, or cancel a task the first one
holds. Only *setting* the assignee is restricted, which is why the rules check
the incoming assignee rather than the stored one, and separately tolerate an
unchanged assignee.

A representative can only ever be assigned their own work, which was already
enforced before this change.

The reverse direction is deliberate too: an administrator may take a task
another administrator holds, but may not push one onto them. You can volunteer
yourself; you cannot volunteer a peer.

What none of this settles is the handover. Reassignment is silent in every
direction — nobody is told when work leaves them, and there is no way to pass on
what has already been done. That is an unresolved design question rather than an
oversight, recorded under **Open design questions** in the roadmap and to be
answered before a version 1 release.

## Archiving a contact

Archiving a contact does not touch its tasks, so its open follow-ups keep
appearing in Today and Overdue while pointing at a contact that has left every
list. The archive confirmation now reports the open-task count so the choice is
informed, and those tasks can be cancelled individually.

An automatic cascade was rejected. A representative archiving a contact whose
follow-up is assigned to an administrator cannot update that task under the
rules, and the failure would abort the archive itself.
