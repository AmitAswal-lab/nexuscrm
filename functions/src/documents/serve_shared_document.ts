import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onRequest} from 'firebase-functions/v2/https';
import type {Request, Response} from 'express';

const tokenPattern = /^[A-Za-z0-9_-]{32,128}$/;

export async function handleSharedDocumentRequest(
  request: Request,
  response: Response,
): Promise<void> {
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    response.status(405).send('Method not allowed.');
    return;
  }

  const token = String(request.query.token ?? '').trim();

  if (!tokenPattern.test(token)) {
    response.status(400).send('This link is not valid.');
    return;
  }

  const firestore = getFirestore();
  const matches = await firestore
    .collectionGroup('documentShares')
    .where('token', '==', token)
    .limit(1)
    .get();

  if (matches.empty) {
    response.status(404).send('This link is no longer available.');
    return;
  }

  const share = matches.docs[0];
  const data = share.data();
  const now = Timestamp.now();

  if (data.revokedAt != null) {
    response.status(410).send('This link has been revoked.');
    return;
  }

  const expiresAt = data.expiresAt as Timestamp | undefined;

  if (!expiresAt || expiresAt.toMillis() <= now.toMillis()) {
    response.status(410).send('This link has expired.');
    return;
  }

  const documentReference = firestore
    .collection('workspaces')
    .doc(String(data.workspaceId))
    .collection('documents')
    .doc(String(data.documentId));
  const documentSnapshot = await documentReference.get();

  if (!documentSnapshot.exists) {
    response.status(404).send('This document is no longer available.');
    return;
  }

  const document = documentSnapshot.data() ?? {};

  if (document.isRetired === true) {
    response.status(410).send('This document has been withdrawn.');
    return;
  }

  const file = getStorage().bucket().file(String(document.storagePath));
  const [exists] = await file.exists();

  if (!exists) {
    response.status(404).send('This document is no longer available.');
    return;
  }

  await share.ref.update({
    openCount: (Number(data.openCount) || 0) + 1,
    lastOpenedAt: now,
  });

  const title = String(document.title ?? 'document').replace(/["\\]/g, '');

  response.setHeader(
    'Content-Type',
    String(document.contentType ?? 'application/octet-stream'),
  );
  response.setHeader(
    'Content-Disposition',
    `inline; filename="${title}"`,
  );
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('X-Content-Type-Options', 'nosniff');

  if (request.method === 'HEAD') {
    response.status(200).end();
    return;
  }

  await new Promise<void>((resolve, reject) => {
    file
      .createReadStream()
      .on('error', reject)
      .on('end', resolve)
      .pipe(response);
  });
}

export const sharedDocument = onRequest(
  {cors: false, invoker: 'public'},
  handleSharedDocumentRequest,
);
