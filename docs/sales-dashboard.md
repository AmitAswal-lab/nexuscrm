# Sales dashboard foundation

## Purpose

The Sales Dashboard is the Home destination for authenticated sales
representatives. It establishes a polished daily-work layout before lead,
task, and follow-up repositories exist.

The foundation does not fabricate CRM records or imply that unavailable
metrics are zero.

## Current presentation

The dashboard contains:

- A Sales Dashboard header
- The signed-in user's display name, with email fallback
- Quick actions for Leads and Tasks
- Overview cards for Leads, Today's Follow-ups, Overdue Tasks, and Pipeline
- Today and Recent Leads sections

Unavailable metrics display an em dash and explain which future feature will
provide the data. Today and Recent Leads similarly explain that their content
will appear after the relevant repositories are connected.

## Responsive behavior

The page is vertically scrollable and constrained to a readable maximum width.

- Phone widths use one horizontal overview card per row.
- Medium widths use two overview columns.
- Wide widths use four overview columns.
- Today and Recent Leads stack on narrow layouts and sit side by side on wider
  layouts.

The shared authenticated shell independently chooses bottom navigation or a
navigation rail.

## Identity

`SalesDashboardPage` reads the authenticated `AuthUser` from `SessionBloc`.
The header prefers a non-empty display name and falls back to the Firebase
email address.

No dashboard-specific state-management object is needed while the page has no
data repository.

## Navigation

Quick actions use the existing sales routes:

```text
Open leads -> /sales/leads
Open tasks -> /sales/tasks
```

The global session guard continues to protect all `/sales` routes.

## Current boundaries

The dashboard foundation intentionally has:

- No `DashboardCubit`
- No dashboard repository
- No Firebase query
- No fake CRM data
- No new package dependency
- No effect on Administrator Home

These boundaries keep presentation separate from lead and task features that
do not yet exist.

## Future integration

Lead/client management will provide:

- Lead totals
- Recent leads
- Basic pipeline summaries

Tasks and follow-ups will provide:

- Today's follow-ups
- Overdue task totals
- Today-section items

When those repositories are available, the unavailable cards should be
replaced with explicit loading, data, empty, and error states. Business logic
should enter a dashboard state-management layer rather than the presentation
widgets.

## Test coverage

Widget and routing tests cover:

- Dashboard content and honest unavailable states
- Display-name and email fallback
- Leads and Tasks quick actions
- Phone and wide layouts
- Responsive overview behavior without overflow
- Sales Home route integration
