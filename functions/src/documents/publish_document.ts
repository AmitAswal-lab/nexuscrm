import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onRequest, type Request} from 'firebase-functions/v2/https';
import type {Response} from 'express';

export const maxDocumentBytes = 10 * 1024 * 1024;

export async function handlePublishDocumentRequest(
  request: Request,
  response: Response,
): Promise<void> {
  if (request.method !== 'POST') {
    response.status(405).json({error: 'method-not-allowed'});
    return;
  }

  const token = bearerToken(request);

  if (token === null) {
    response.status(401).json({error: 'unauthenticated'});
    return;
  }

  let userId: string;

  try {
    userId = (await getAuth().verifyIdToken(token)).uid;
  } catch {
    response.status(401).json({error: 'unauthenticated'});
    return;
  }

  const workspaceId = identifier(request.query.workspaceId);
  const title = text(request.query.title, 120);
  const description = text(request.query.description, 1000);

  if (workspaceId === null || title === null) {
    response.status(400).json({error: 'invalid-argument'});
    return;
  }

  const firestore = getFirestore();
  const membership = await firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('members')
    .doc(userId)
    .get();
  const member = membership.data();

  if (
    !membership.exists ||
    member?.role !== 'admin' ||
    member?.status !== 'active'
  ) {
    response.status(403).json({error: 'permission-denied'});
    return;
  }

  const bytes = request.rawBody;

  if (!bytes || bytes.length === 0) {
    response.status(400).json({error: 'empty-body'});
    return;
  }

  if (bytes.length > maxDocumentBytes) {
    response.status(413).json({error: 'too-large'});
    return;
  }

  const contentType =
    typeof request.headers['content-type'] === 'string' &&
    request.headers['content-type'].length > 0
      ? request.headers['content-type']
      : 'application/octet-stream';

  const reference = firestore
    .collection('workspaces')
    .doc(workspaceId)
    .collection('documents')
    .doc();
  const storagePath = `workspaces/${workspaceId}/documents/${reference.id}`;

  await getStorage()
    .bucket()
    .file(storagePath)
    .save(bytes, {contentType, resumable: false});

  try {
    await reference.create({
      workspaceId,
      title,
      description,
      storagePath,
      contentType,
      sizeBytes: bytes.length,
      isRetired: false,
      uploadedByUserId: userId,
      updatedByUserId: userId,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await getStorage().bucket().file(storagePath).delete({ignoreNotFound: true});
    throw error;
  }

  response.status(201).json({documentId: reference.id});
}

function bearerToken(request: Request): string | null {
  const header = request.headers.authorization;

  if (typeof header !== 'string' || !header.startsWith('Bearer ')) {
    return null;
  }

  const token = header.slice('Bearer '.length).trim();
  return token.length > 0 ? token : null;
}

function identifier(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();

  return normalized.length > 0 && !normalized.includes('/')
    ? normalized
    : null;
}

function text(value: unknown, limit: number): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();

  return normalized.length > 0 && normalized.length <= limit
    ? normalized
    : null;
}

export const publishDocument = onRequest(
  {cors: false, memory: '512MiB', timeoutSeconds: 120},
  handlePublishDocumentRequest,
);
