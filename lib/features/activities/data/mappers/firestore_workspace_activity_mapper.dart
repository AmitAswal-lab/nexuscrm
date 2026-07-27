import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/activities/domain/entities/workspace_activity.dart';

abstract final class FirestoreWorkspaceActivityMapper {
  static const callNoteType = 'call_note';

  static bool isType(
    DocumentSnapshot<Map<String, dynamic>> document,
    String type,
  ) => document.data()?['type'] == type;

  static WorkspaceActivity fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.id.trim().isEmpty ||
        document.reference.parent.id != 'activities' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid activity document path.');
    }

    final workspaceId = _requiredString(data, 'workspaceId');

    if (workspaceId != workspaceReference.id) {
      throw const FormatException('Activity workspace ID does not match path.');
    }

    return WorkspaceActivity(
      id: document.id,
      workspaceId: workspaceId,
      type: _type(_requiredString(data, 'type')),
      contactId: _requiredString(data, 'contactId'),
      actorUserId: _requiredString(data, 'actorUserId'),
      createdAt: _requiredTimestamp(data, 'createdAt'),
      contactName: _optionalString(data, 'contactName'),
      detail: _detail(data),
    );
  }

  static Map<String, Object?> leadCreatedData({
    required String workspaceId,
    required String contactId,
    required String contactName,
    required String actorUserId,
  }) => _eventData(
    type: 'lead_created',
    workspaceId: workspaceId,
    contactId: contactId,
    contactName: contactName,
    actorUserId: actorUserId,
  );

  static Map<String, Object?> leadConvertedData({
    required String workspaceId,
    required String contactId,
    required String contactName,
    required String actorUserId,
  }) => _eventData(
    type: 'lead_converted',
    workspaceId: workspaceId,
    contactId: contactId,
    contactName: contactName,
    actorUserId: actorUserId,
  );

  static Map<String, Object?> taskCompletedData({
    required String workspaceId,
    required String contactId,
    required String contactName,
    required String actorUserId,
    required String taskId,
    required String taskTitle,
  }) => <String, Object?>{
    ..._eventData(
      type: 'task_completed',
      workspaceId: workspaceId,
      contactId: contactId,
      contactName: contactName,
      actorUserId: actorUserId,
    ),
    'taskId': _normalized(taskId, 'taskId'),
    'taskTitle': _normalized(taskTitle, 'taskTitle'),
  };

  static Map<String, Object?> _eventData({
    required String type,
    required String workspaceId,
    required String contactId,
    required String contactName,
    required String actorUserId,
  }) => <String, Object?>{
    'workspaceId': _normalized(workspaceId, 'workspaceId'),
    'type': type,
    'contactId': _normalized(contactId, 'contactId'),
    'contactName': _normalized(contactName, 'contactName'),
    'actorUserId': _normalized(actorUserId, 'actorUserId'),
    'createdAt': FieldValue.serverTimestamp(),
  };

  static String? _detail(Map<String, dynamic> data) {
    final title = data['taskTitle'];
    if (title is String && title.trim().isNotEmpty) return title.trim();

    final outcome = data['outcome'];
    return switch (outcome) {
      'connected' => 'Connected',
      'voicemail' => 'Voicemail',
      'no_answer' => 'No answer',
      'wrong_number' => 'Wrong number',
      'other' => 'Other outcome',
      _ => null,
    };
  }

  static String typeName(WorkspaceActivityType type) => switch (type) {
    WorkspaceActivityType.callLogged => callNoteType,
    WorkspaceActivityType.leadCreated => 'lead_created',
    WorkspaceActivityType.leadConverted => 'lead_converted',
    WorkspaceActivityType.taskCompleted => 'task_completed',
  };

  static WorkspaceActivityType _type(String value) => switch (value) {
    callNoteType => WorkspaceActivityType.callLogged,
    'lead_created' => WorkspaceActivityType.leadCreated,
    'lead_converted' => WorkspaceActivityType.leadConverted,
    'task_completed' => WorkspaceActivityType.taskCompleted,
    _ => throw FormatException('Unsupported activity type: $value.'),
  };

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid activity field: $field.');
    }

    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];

    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static DateTime _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! Timestamp) {
      throw FormatException('Invalid activity field: $field.');
    }

    return value.toDate();
  }

  static String _normalized(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException('Invalid activity field: $field.');
    }

    return normalized;
  }
}
