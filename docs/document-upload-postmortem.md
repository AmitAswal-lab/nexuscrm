# The upload that never left the phone

An administrator tried to publish a document and got told they were not an
administrator. They were. It took four attempts to fix, and the first three were
aimed at the wrong half of the system.

This is what happened and what we changed so it cannot hide again.

## What it looked like

Signed in as an administrator, on the Documents screen, tapping Add and choosing
a file produced one message:

> Only an administrator can change the document library.

Everything else in the app worked normally. Leads loaded, tasks loaded, and the
document list itself loaded. Only the upload failed, and it failed every single
time.

## Why the message was believed

The message named a cause, and the cause sounded plausible. Uploading is an
administrator-only action, so a permission error on an administrator-only action
reads as a permission bug. Three fixes followed from that reading, and all three
were attempts to make the server grant permission that it had never been asked
for.

The first tried to gate uploads in the Cloud Storage rules, using a rule that
reads the member's role out of Firestore. That did not work, and it failed in a
particularly unhelpful way: the rules compiler reported success even though the
rule called the wrong function, and a rule that fails while being evaluated
simply denies, with no log and no error.

The second added the permission grant that a rule reading across services needs.
Still denied.

The third gave up on rules entirely and moved the upload into a Cloud Function,
so that the role check runs in ordinary server code with the Admin SDK and no
client can touch the bucket at all. That was a genuine improvement to the design.
It also did not fix the bug.

## The question that cracked it

The third attempt changed one thing that mattered more than the fix itself: the
new path was a Cloud Function, and Cloud Functions write logs.

So instead of asking "why is permission being denied", we asked something with a
yes or no answer:

**Did the request ever arrive?**

A test request sent from a laptop appeared in the log within seconds. The user's
attempt, made half an hour earlier, had left nothing at all. Not a rejection, not
an error, not a single line.

The phone had never sent anything. Every fix so far had been aimed at a door
nobody was knocking on.

## The actual cause

Working backwards from the message, the error had exactly three possible sources
in the client. Two of them involve talking to the server, and both would have
left a log entry. That left one:

```dart
final token = await idToken();

if (token == null || token.isEmpty) {
  throw const DocumentFailure(DocumentFailureCode.permissionDenied);
}
```

The app asks Firebase for the signed-in user's token, gets nothing back, and
gives up before making the request. The token fetch was written as
`getIdToken()`, which returns the cached token and can hand back nothing when
that cached copy has gone stale. Firebase ID tokens last an hour; the session had
been open far longer.

## Why it hid so well

The app looked completely signed in the entire time, because it was.

Firestore manages its own credentials internally and refreshes them on its own
schedule. It never calls `getIdToken()`. So every screen backed by Firestore —
leads, tasks, the document list on the very same page — kept working perfectly
while that one call returned nothing.

The one part of the app that asked for the token directly was the only part that
broke, and it was also the newest part, which made it look like the new feature
was at fault rather than the way it fetched the token.

## The fix

One argument:

```dart
FirebaseAuth.instance.currentUser?.getIdToken(true)
```

`true` forces Firebase to fetch a fresh token instead of trusting the cached one.

## What made it a four-round bug

Two things, and neither was the missing token.

**The error message lied.** A missing token and a rejected role produced the same
sentence. So did an HTTP 401 and an HTTP 403, which are opposite problems — 401
means the token was bad, 403 means the person was not allowed. Collapsing all of
that into one message meant the app could not tell us which of four different
failures had happened, and every one of them pointed at the server.

Now they are separate. A missing or rejected token says the sign-in has expired.
Only a genuine role rejection claims the user is not an administrator.

**The upload path had no tests.** Not one. The share flow was tested, the rules
were tested, the function was tested, and the single line that actually failed
was covered by nothing. It now has eleven tests covering the empty-token case,
every status code, and the exact request that gets sent. Two of them fail against
the old code.

## What to take from it

Trust the message about *what* failed, never about *why*. The app said permission
was denied. Permission was not denied. Nobody had asked.

Prefer a question with a yes-or-no answer over a better theory. "Why is
permission denied" produced three plausible theories and three wrong fixes. "Did
the request arrive" produced the answer in a single log query.

Build the thing that can answer that question early. The bug became findable the
moment the code path started writing logs — not because logging fixed anything,
but because it made a silent failure observable. The first three attempts were
debugging a system that could not be watched.

An error message that covers several causes will eventually send someone the
wrong way. Each distinct cause deserves its own message, and it is worth adding
that distinction before it is needed rather than after.
