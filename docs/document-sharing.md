# Document sharing

A representative finishes a call and needs to send the client a brochure or a
quote. They can do that without ever holding the file.

## Why not attach the file

The obvious approach is a share sheet: pick a file, hand it to WhatsApp. It was
rejected for three reasons.

Nothing controls which file gets sent. A representative attaches last quarter's
price list because that is what sits in their downloads folder, and no one
knows. Nothing approves it, nothing records it, and once it has left a personal
device it cannot be withdrawn.

The mechanism also cannot be made safe. A share sheet requires a local file
path, so the document must reach the phone before it can be attached, and
`mailto:` links cannot carry attachments at all. "Send without downloading" is
not achievable through attachments.

So the document is not sent. A link to it is.

## How it works

An administrator publishes documents to the workspace library. A representative
browses that library and picks one. The application creates a share, and sends
the **link** as ordinary text through WhatsApp or email. The client opens the
link and the bytes are served from the workspace.

The representative sees titles and sizes. They never receive the file.

## What enforces that

`storage.rules` denies everything to every client — read and write, for
representatives, administrators, and signed-out visitors alike. The bucket is
reachable only by Cloud Functions through the Admin SDK, which does not evaluate
rules.

Both directions therefore run through functions. `publishDocument` accepts an
upload, and `sharedDocument` serves one.

## Publishing

`publishDocument` takes the file as the request body, with the workspace and
title as query parameters and the caller's ID token as a bearer header. It
verifies the token, reads the caller's membership with the Admin SDK, and
refuses anyone who is not an active administrator. Uploads are capped at ten
megabytes.

The file and its Firestore record are written together, and the file is deleted
again if the record fails, so a rejected or half-finished publish cannot leave an
unreachable object behind.

Storage rules were tried first and abandoned. Gating uploads by role there means
a Storage rule reading Firestore — a cross-service rule. That needs a permission
grant the CLI does not perform, fails silently when it is missing, is accepted by
the rules compiler even when the function names are wrong, and behaves
differently in the emulator than in production. It cost three deploys and never
worked. Moving the check into server code removed the whole class of problem and
made the bucket stricter, because no client needs write access at all.

## The link endpoint

`sharedDocument` is an HTTPS function that checks, in order:

1. The token is well formed.
2. A share exists for it.
3. The share has not been revoked.
4. The share has not expired.
5. The document has not been withdrawn since.

Only then does it stream the file, and it records the open first. A collection
group index on `token` backs the lookup.

Streaming rather than redirecting to a signed URL is deliberate. A signed URL
cannot be withdrawn once issued, and it produces no record of use. Serving
through the function keeps revocation immediate and gives an audit trail for
free, at the cost of egress through the function.

## Shares

A share stores the document, the contact, the channel, who sent it, when it
expires, and how many times it has been opened. Links last seven days by
default and can be revoked at any moment from the contact's share screen.

The rules require a token of at least 32 characters, a sender matching the
authenticated user, a server timestamp for creation, and an open count starting
at zero, so a share cannot be created pre-inflated or on someone else's behalf.
A representative may only share with a contact they own; an administrator may
share with any active contact.

## What is deliberately absent

Documents cannot be deleted, only withdrawn, matching contacts and tasks.

Sharing is not recorded in the workspace activity feed. The feed was kept
deliberately short in milestone 9, and share history already lives on the
contact.

Nothing notifies the recipient that a link expired. They ask again, and the
representative sends a fresh one.
