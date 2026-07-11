import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';

abstract final class FirestoreCallNoteMapper {
  static CallNote fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.id.trim().isEmpty ||
        document.reference.parent.id != 'activities' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid call-note document path.');
    }

    final workspaceId = _requiredIdentifier(data, 'workspaceId');

    if (workspaceId != workspaceReference.id) {
      throw const FormatException(
        'Call-note workspace ID does not match path.',
      );
    }

    if (_requiredString(data, 'type') != 'call_note') {
      throw const FormatException('Unsupported activity type.');
    }

    return CallNote(
      id: document.id,
      workspaceId: workspaceId,
      contactId: _requiredIdentifier(data, 'contactId'),
      outcome: _callOutcome(_requiredString(data, 'outcome')),
      note: _optionalNote(data, 'note'),
      actorUserId: _requiredIdentifier(data, 'actorUserId'),
      createdAt: _requiredTimestamp(data, 'createdAt'),
      nextTaskId: _optionalIdentifier(data, 'nextTaskId'),
    );
  }

  static Map<String, Object?> createCallNoteData({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required CallNoteInput input,
  }) {
    final note = input.note?.trim();

    if (note != null && note.length > 1000) {
      throw const FormatException('Call note is too long.');
    }

    return <String, Object?>{
      'workspaceId': _normalizedIdentifier(workspaceId, 'workspaceId'),
      'type': 'call_note',
      'contactId': _normalizedIdentifier(contactId, 'contactId'),
      'outcome': switch (input.outcome) {
        CallOutcome.connected => 'connected',
        CallOutcome.voicemail => 'voicemail',
        CallOutcome.noAnswer => 'no_answer',
        CallOutcome.wrongNumber => 'wrong_number',
        CallOutcome.other => 'other',
      },
      'note': note == null || note.isEmpty ? null : note,
      'actorUserId': _normalizedIdentifier(actorUserId, 'actorUserId'),
      'createdAt': FieldValue.serverTimestamp(),
      // Linking a follow-up task is intentionally introduced with that
      // transactional workflow in checkpoint 3.
      'nextTaskId': null,
    };
  }

  static CallOutcome _callOutcome(String value) {
    return switch (value) {
      'connected' => CallOutcome.connected,
      'voicemail' => CallOutcome.voicemail,
      'no_answer' => CallOutcome.noAnswer,
      'wrong_number' => CallOutcome.wrongNumber,
      'other' => CallOutcome.other,
      _ => throw FormatException('Unsupported call outcome: $value.'),
    };
  }

  static String _requiredIdentifier(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String) {
      throw FormatException('Invalid call-note identifier: $field.');
    }

    return _normalizedIdentifier(value, field);
  }

  static String? _optionalIdentifier(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw FormatException('Invalid optional call-note identifier: $field.');
    }

    return _normalizedIdentifier(value, field);
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid call-note field: $field.');
    }

    return value.trim();
  }

  static String? _optionalNote(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String ||
        value.trim().isEmpty ||
        value.trim().length > 1000) {
      throw FormatException('Invalid optional call-note field: $field.');
    }

    return value.trim();
  }

  static DateTime _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! Timestamp) {
      throw FormatException('Invalid call-note timestamp: $field.');
    }

    return value.toDate().toUtc();
  }

  static String _normalizedIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid call-note identifier: $field.');
    }

    return normalized;
  }
}
