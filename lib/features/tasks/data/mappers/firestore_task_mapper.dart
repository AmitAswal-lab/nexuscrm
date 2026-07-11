import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/tasks/domain/entities/crm_task.dart';
import 'package:nexuscrm/features/tasks/domain/entities/task_input.dart';

abstract final class FirestoreTaskMapper {
  static CrmTask fromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.id.trim().isEmpty ||
        document.reference.parent.id != 'tasks' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid task document path.');
    }

    final workspaceId = _requiredIdentifier(data, 'workspaceId');

    if (workspaceId != workspaceReference.id) {
      throw const FormatException('Task workspace ID does not match path.');
    }

    final completionCount = _requiredNonNegativeInt(data, 'completionCount');
    final lastCompletedAt = _optionalTimestamp(data, 'lastCompletedAt');
    final lastCompletedByUserId = _optionalIdentifier(
      data,
      'lastCompletedByUserId',
    );
    final status = _taskStatus(_requiredString(data, 'status'));

    if (completionCount == 0 &&
        (lastCompletedAt != null || lastCompletedByUserId != null)) {
      throw const FormatException(
        'Uncompleted tasks cannot contain completion metadata.',
      );
    }

    if (completionCount > 0 &&
        (lastCompletedAt == null || lastCompletedByUserId == null)) {
      throw const FormatException(
        'Completed task history requires completion metadata.',
      );
    }

    if (status == TaskStatus.completed && completionCount == 0) {
      throw const FormatException(
        'Completed tasks require completion history.',
      );
    }

    return CrmTask(
      id: document.id,
      workspaceId: workspaceId,
      contactId: _requiredIdentifier(data, 'contactId'),
      kind: _taskKind(_requiredString(data, 'kind')),
      title: _requiredTitle(data, 'title'),
      notes: _optionalNotes(data, 'notes'),
      assigneeId: _requiredIdentifier(data, 'assigneeId'),
      dueOn: _requiredDate(data, 'dueOn'),
      status: status,
      completionCount: completionCount,
      lastCompletedAt: lastCompletedAt,
      lastCompletedByUserId: lastCompletedByUserId,
      createdByUserId: _requiredIdentifier(data, 'createdByUserId'),
      updatedByUserId: _requiredIdentifier(data, 'updatedByUserId'),
      createdAt: _requiredTimestamp(data, 'createdAt'),
      updatedAt: _requiredTimestamp(data, 'updatedAt'),
    );
  }

  static Map<String, Object?> createTaskData({
    required String workspaceId,
    required String actorUserId,
    required TaskInput input,
  }) {
    final normalized = _NormalizedTaskInput.fromInput(input);
    final actor = _normalizedIdentifier(actorUserId, 'actorUserId');

    return <String, Object?>{
      'workspaceId': _normalizedIdentifier(workspaceId, 'workspaceId'),
      ...normalized.toMap(),
      'status': 'open',
      'completionCount': 0,
      'lastCompletedAt': null,
      'lastCompletedByUserId': null,
      'createdByUserId': actor,
      'updatedByUserId': actor,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> updateTaskData({
    required String actorUserId,
    required TaskInput input,
  }) {
    final normalized = _NormalizedTaskInput.fromInput(input);

    return <String, Object?>{
      ...normalized.toEditableMap(),
      'updatedByUserId': _normalizedIdentifier(actorUserId, 'actorUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> completeTaskData({
    required String actorUserId,
    required int completionCount,
  }) {
    if (completionCount < 0) {
      throw const FormatException('Invalid task completion count.');
    }

    return <String, Object?>{
      'status': 'completed',
      'completionCount': completionCount + 1,
      'lastCompletedAt': FieldValue.serverTimestamp(),
      'lastCompletedByUserId': _normalizedIdentifier(
        actorUserId,
        'actorUserId',
      ),
      'updatedByUserId': _normalizedIdentifier(actorUserId, 'actorUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> reopenTaskData({required String actorUserId}) {
    final actor = _normalizedIdentifier(actorUserId, 'actorUserId');

    return <String, Object?>{
      'status': 'open',
      'updatedByUserId': actor,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static TaskKind _taskKind(String value) {
    return switch (value) {
      'task' => TaskKind.task,
      'follow_up' => TaskKind.followUp,
      _ => throw FormatException('Unsupported task kind: $value.'),
    };
  }

  static TaskStatus _taskStatus(String value) {
    return switch (value) {
      'open' => TaskStatus.open,
      'completed' => TaskStatus.completed,
      _ => throw FormatException('Unsupported task status: $value.'),
    };
  }

  static String _requiredIdentifier(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String) {
      throw FormatException('Invalid task identifier: $field.');
    }

    return _normalizedIdentifier(value, field);
  }

  static String? _optionalIdentifier(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw FormatException('Invalid optional task identifier: $field.');
    }

    return _normalizedIdentifier(value, field);
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid task field: $field.');
    }

    return value.trim();
  }

  static String _requiredTitle(Map<String, dynamic> data, String field) {
    final value = _requiredString(data, field);

    if (value.length > 120) {
      throw FormatException('Task title is too long.');
    }

    return value;
  }

  static String? _optionalNotes(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String ||
        value.trim().isEmpty ||
        value.trim().length > 1000) {
      throw FormatException('Invalid optional task field: $field.');
    }

    return value.trim();
  }

  static String _requiredDate(Map<String, dynamic> data, String field) {
    final value = _requiredString(data, field);
    return _normalizedDate(value, field);
  }

  static DateTime _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! Timestamp) {
      throw FormatException('Invalid task timestamp: $field.');
    }

    return value.toDate().toUtc();
  }

  static DateTime? _optionalTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! Timestamp) {
      throw FormatException('Invalid optional task timestamp: $field.');
    }

    return value.toDate().toUtc();
  }

  static int _requiredNonNegativeInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! int || value < 0) {
      throw FormatException('Invalid task count: $field.');
    }

    return value;
  }

  static String _normalizedIdentifier(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw FormatException('Invalid task identifier: $field.');
    }

    return normalized;
  }

  static String _normalizedDate(String value, String field) {
    final normalized = value.trim();
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(normalized);

    if (match == null) {
      throw FormatException('Invalid task date: $field.');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Invalid task date: $field.');
    }

    return normalized;
  }
}

final class _NormalizedTaskInput {
  const _NormalizedTaskInput({
    required this.contactId,
    required this.kind,
    required this.title,
    required this.notes,
    required this.assigneeId,
    required this.dueOn,
  });

  factory _NormalizedTaskInput.fromInput(TaskInput input) {
    final notes = input.notes?.trim();

    if (notes != null && notes.length > 1000) {
      throw const FormatException('Task notes are too long.');
    }

    final title = input.title.trim();

    if (title.isEmpty || title.length > 120) {
      throw const FormatException('Invalid task title.');
    }

    return _NormalizedTaskInput(
      contactId: FirestoreTaskMapper._normalizedIdentifier(
        input.contactId,
        'contactId',
      ),
      kind: input.kind,
      title: title,
      notes: notes == null || notes.isEmpty ? null : notes,
      assigneeId: FirestoreTaskMapper._normalizedIdentifier(
        input.assigneeId,
        'assigneeId',
      ),
      dueOn: FirestoreTaskMapper._normalizedDate(input.dueOn, 'dueOn'),
    );
  }

  final String contactId;
  final TaskKind kind;
  final String title;
  final String? notes;
  final String assigneeId;
  final String dueOn;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'contactId': contactId,
      'kind': switch (kind) {
        TaskKind.task => 'task',
        TaskKind.followUp => 'follow_up',
      },
      'title': title,
      'notes': notes,
      'assigneeId': assigneeId,
      'dueOn': dueOn,
    };
  }

  Map<String, Object?> toEditableMap() {
    final data = toMap()..remove('contactId');
    return data;
  }
}
