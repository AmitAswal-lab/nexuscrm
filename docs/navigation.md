# Navigation shell

## Purpose

The navigation shell gives authenticated users a stable way to reach current
and planned CRM features. It is intentionally separate from feature
implementation so dashboard, lead, task, and administration pages can replace
placeholders without restructuring application routing.

Administrators and sales representatives share four primary destinations:

- Home
- Leads
- Tasks
- More

The destination labels stay consistent while their content and permissions are
role-specific.

## Adaptive layout

The shell uses the available logical width:

- Below 600 logical pixels: Material 3 bottom `NavigationBar`
- At 600 logical pixels and wider: labeled `NavigationRail`

This keeps phone navigation familiar while using horizontal space more
effectively on tablets and wide windows.

## Route map

| Destination | Administrator | Sales representative |
|---|---|---|
| Home | `/admin/home` | `/sales/home` |
| Leads | `/admin/leads` | `/sales/leads` |
| Tasks | `/admin/tasks` | `/sales/tasks` |
| More | `/admin/more` | `/sales/more` |

`/admin` redirects to `/admin/home`, and `/sales` redirects to `/sales/home`.
These root paths remain useful as stable role entry points.

## Stateful branches

Each role uses `StatefulShellRoute.indexedStack` with one branch per primary
destination. Switching tabs keeps inactive branches alive, allowing future
nested feature pages to preserve navigation and interface state.

Selecting the active destination again returns that branch to its initial
location. This follows common mobile navigation behavior and provides a
predictable way back to a tab's root page.

## Role protection

`SessionBloc` remains the source of authenticated role state. Global router
redirects enforce these boundaries:

- Administrators may access only `/admin` routes.
- Sales representatives may access only `/sales` routes.
- Cross-role navigation returns the user to their own Home route.
- Unauthenticated and restricted session states remain outside the
  authenticated shell.

Route protection improves navigation behavior, but Firestore rules remain the
authoritative data-security boundary.

## Placeholder responsibilities

The current placeholder pages communicate upcoming scope without providing
fake CRM data. Feature milestones replace them incrementally:

- Sales Dashboard has replaced the sales Home placeholder.
- Lead/client management replaces Leads placeholders.
- Tasks and follow-ups replace Tasks placeholders.
- Administrator overview arrives with admin activity and reporting.

More contains account-level and secondary actions. Sign-out is located only in
More so primary feature pages remain focused. Future administrator team
management and activity links can also enter through this destination.

## Adding a feature route

When extending a primary branch:

1. Keep the role prefix (`/admin` or `/sales`).
2. Add detail and editor routes beneath the appropriate primary destination.
3. Preserve global session and role redirects.
4. Avoid placing feature business logic inside the shell.
5. Add routing tests for direct navigation, tab switching, and role denial.

## Test coverage

Widget tests verify:

- Administrator and sales phone navigation
- Role-specific destination content
- Root redirects
- Cross-role protection
- More-only sign-out and return to sign-in
- Wide-layout navigation rail
- Selected destination behavior
- Existing access-denied routing
