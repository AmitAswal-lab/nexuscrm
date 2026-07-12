import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/activities/data/mappers/firestore_call_note_mapper.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';

void main() {
  test('creates normalized append-only call-note data', () {
    final data = FirestoreCallNoteMapper.createCallNoteData(
      workspaceId: ' workspace-one ',
      contactId: ' contact-one ',
      actorUserId: ' sales-user ',
      input: const CallNoteInput(
        outcome: CallOutcome.noAnswer,
        note: ' Try again tomorrow ',
      ),
    );

    expect(data['workspaceId'], 'workspace-one');
    expect(data['type'], 'call_note');
    expect(data['contactId'], 'contact-one');
    expect(data['outcome'], 'no_answer');
    expect(data['note'], 'Try again tomorrow');
    expect(data['actorUserId'], 'sales-user');
    expect(data['createdAt'], isA<FieldValue>());
    expect(data['nextTaskId'], isNull);
  });

  test('normalizes an empty note to null', () {
    final data = FirestoreCallNoteMapper.createCallNoteData(
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
      actorUserId: 'sales-user',
      input: const CallNoteInput(outcome: CallOutcome.voicemail, note: '   '),
    );

    expect(data['note'], isNull);
  });

  test('rejects malformed identifiers and oversized notes', () {
    expect(
      () => FirestoreCallNoteMapper.createCallNoteData(
        workspaceId: 'workspace-one',
        contactId: 'contacts/contact-one',
        actorUserId: 'sales-user',
        input: const CallNoteInput(outcome: CallOutcome.connected, note: null),
      ),
      throwsFormatException,
    );
    expect(
      () => FirestoreCallNoteMapper.createCallNoteData(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'sales-user',
        input: CallNoteInput(outcome: CallOutcome.other, note: 'x' * 1001),
      ),
      throwsFormatException,
    );
  });
}
