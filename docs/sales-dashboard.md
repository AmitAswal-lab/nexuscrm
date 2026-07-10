# Sales dashboard

## Purpose

The Sales Dashboard is the Home destination for authenticated sales
representatives. Contact metrics use the real owner-scoped contact stream.
Task and follow-up areas remain explicitly unavailable until their repository
exists.

## Current presentation

The dashboard contains:

- A Sales Dashboard header
- The signed-in user's display name, with email fallback
- Quick actions for Leads and Tasks
- Real overview counts for Leads and Clients
- Unavailable cards for Today's Follow-ups and Overdue Tasks
- Pipeline-stage counts for New, Contacted, Qualified, Proposal, and Lost
- Recently updated contacts
- Today placeholder for the future task milestone

Unavailable task metrics display an em dash and explain which future feature
will provide the data. Contact sections expose loading, empty, failure, retry,
and success states.

## Responsive behavior

The page is vertically scrollable and constrained to a readable maximum width.

- Phone widths use one horizontal overview card per row.
- Medium widths use two overview columns.
- Wide widths use four overview columns.
- Today and Recent Contacts stack on narrow layouts and sit side by side on wider
  layouts.

The shared authenticated shell independently chooses bottom navigation or a
navigation rail.

## Identity

`SalesDashboardPage` reads the authenticated `AuthUser` from `SessionBloc`.
The header prefers a non-empty display name and falls back to the Firebase
email address.

`SalesDashboardCubit` subscribes to `ContactRepository.watchContacts` with an
`OwnedContactAccess` scope. Its state derives lead totals, client totals,
pipeline-stage counts, active pipeline count, and the three most recently
updated contacts.

## Navigation

Quick actions use the existing sales routes:

```text
Open leads -> /sales/leads
Open tasks -> /sales/tasks
Recent contact -> /sales/leads/:contactId
```

The global session guard continues to protect all `/sales` routes.

## Current boundaries

The dashboard reuses the contact repository rather than introducing a separate
dashboard data source. It still has no fake CRM data, no new package
dependency, and no effect on Administrator Home.

## Future integration

Tasks and follow-ups will provide:

- Today's follow-ups
- Overdue task totals
- Today-section items

When the task repository is available, its unavailable cards and Today section
will be replaced with explicit loading, data, empty, and error states.

## Test coverage

Widget and routing tests cover:

- Real contact metrics and honest task-unavailable states
- Owner-scoped stream handling, failures, and retry
- Pipeline derivation and recent-contact navigation
- Display-name and email fallback
- Leads and Tasks quick actions
- Phone and wide layouts
- Responsive overview behavior without overflow
- Sales Home route integration
