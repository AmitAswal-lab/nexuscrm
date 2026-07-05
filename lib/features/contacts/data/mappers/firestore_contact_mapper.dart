import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';

abstract final class FirestoreContactMapper {
  static CrmContact fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final workspaceReference = document.reference.parent.parent;

    if (data == null ||
        document.id.trim().isEmpty ||
        document.reference.parent.id != 'contacts' ||
        workspaceReference == null ||
        workspaceReference.parent.id != 'workspaces') {
      throw const FormatException('Invalid contact document path.');
    }

    final workspaceId = _requiredString(data, 'workspaceId');

    if (workspaceId != workspaceReference.id) {
      throw const FormatException('Contact workspace ID does not match path.');
    }

    final common = _CommonContactData.fromMap(data);
    final kind = _requiredString(data, 'kind');

    if (kind == 'lead' &&
        (data['convertedAt'] != null || data['convertedByUserId'] != null)) {
      throw const FormatException(
        'Lead contacts cannot contain conversion metadata.',
      );
    }

    if (kind == 'client' && data['leadStage'] != null) {
      throw const FormatException(
        'Client contacts cannot contain a lead stage.',
      );
    }

    return switch (kind) {
      'lead' => Lead(
        id: document.id,
        workspaceId: workspaceId,
        fullName: common.fullName,
        companyName: common.companyName,
        email: common.email,
        phone: common.phone,
        notes: common.notes,
        ownerId: common.ownerId,
        stage: _parseLeadStage(_requiredString(data, 'leadStage')),
        isArchived: common.isArchived,
        createdByUserId: common.createdByUserId,
        updatedByUserId: common.updatedByUserId,
        createdAt: common.createdAt,
        updatedAt: common.updatedAt,
      ),
      'client' => ClientContact(
        id: document.id,
        workspaceId: workspaceId,
        fullName: common.fullName,
        companyName: common.companyName,
        email: common.email,
        phone: common.phone,
        notes: common.notes,
        ownerId: common.ownerId,
        isArchived: common.isArchived,
        createdByUserId: common.createdByUserId,
        updatedByUserId: common.updatedByUserId,
        createdAt: common.createdAt,
        updatedAt: common.updatedAt,
        convertedAt: _requiredTimestamp(data, 'convertedAt'),
        convertedByUserId: _requiredString(data, 'convertedByUserId'),
      ),
      _ => throw FormatException('Unsupported contact kind: $kind.'),
    };
  }

  static Map<String, Object?> createLeadData({
    required String workspaceId,
    required String actorUserId,
    required LeadInput input,
  }) {
    final normalized = _NormalizedInput.fromInput(input);

    return <String, Object?>{
      'workspaceId': _normalizedRequired(workspaceId, 'workspaceId'),
      'kind': 'lead',
      ...normalized.toMap(),
      'leadStage': _leadStageValue(input.stage),
      'isArchived': false,
      'createdByUserId': _normalizedRequired(actorUserId, 'createdByUserId'),
      'updatedByUserId': _normalizedRequired(actorUserId, 'updatedByUserId'),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'convertedAt': null,
      'convertedByUserId': null,
    };
  }

  static Map<String, Object?> updateLeadData({
    required String actorUserId,
    required LeadInput input,
  }) {
    final normalized = _NormalizedInput.fromInput(input);

    return <String, Object?>{
      ...normalized.toMap(),
      'leadStage': _leadStageValue(input.stage),
      'updatedByUserId': _normalizedRequired(actorUserId, 'updatedByUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> updateClientData({
    required String actorUserId,
    required ClientInput input,
  }) {
    final normalized = _NormalizedInput.fromInput(input);

    return <String, Object?>{
      ...normalized.toMap(),
      'updatedByUserId': _normalizedRequired(actorUserId, 'updatedByUserId'),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, Object?> convertLeadData({required String actorUserId}) {
    final normalizedActor = _normalizedRequired(
      actorUserId,
      'convertedByUserId',
    );

    return <String, Object?>{
      'kind': 'client',
      'leadStage': null,
      'convertedAt': FieldValue.serverTimestamp(),
      'convertedByUserId': normalizedActor,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': normalizedActor,
    };
  }

  static Map<String, Object?> archiveContactData({
    required String actorUserId,
  }) {
    return <String, Object?>{
      'isArchived': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUserId': _normalizedRequired(actorUserId, 'updatedByUserId'),
    };
  }

  static LeadStage _parseLeadStage(String value) {
    return switch (value) {
      'new' => LeadStage.newLead,
      'contacted' => LeadStage.contacted,
      'qualified' => LeadStage.qualified,
      'proposal' => LeadStage.proposal,
      'lost' => LeadStage.lost,
      _ => throw FormatException('Unsupported lead stage: $value.'),
    };
  }

  static String _leadStageValue(LeadStage stage) {
    return switch (stage) {
      LeadStage.newLead => 'new',
      LeadStage.contacted => 'contacted',
      LeadStage.qualified => 'qualified',
      LeadStage.proposal => 'proposal',
      LeadStage.lost => 'lost',
    };
  }

  static String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid contact field: $field.');
    }

    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid optional contact field: $field.');
    }

    return value.trim();
  }

  static DateTime _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! Timestamp) {
      throw FormatException('Invalid contact timestamp: $field.');
    }

    return value.toDate().toUtc();
  }

  static bool _requiredBool(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is! bool) {
      throw FormatException('Invalid contact boolean: $field.');
    }

    return value;
  }

  static String _normalizedRequired(String value, String field) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw FormatException('Invalid required contact input: $field.');
    }

    return normalized;
  }

  static String? _normalizedOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

final class _CommonContactData {
  const _CommonContactData({
    required this.fullName,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.notes,
    required this.ownerId,
    required this.isArchived,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory _CommonContactData.fromMap(Map<String, dynamic> data) {
    final email = FirestoreContactMapper._optionalString(data, 'email');
    final phone = FirestoreContactMapper._optionalString(data, 'phone');

    if (email == null && phone == null) {
      throw const FormatException(
        'A contact requires an email address or phone number.',
      );
    }

    return _CommonContactData(
      fullName: FirestoreContactMapper._requiredString(data, 'fullName'),
      companyName: FirestoreContactMapper._optionalString(data, 'companyName'),
      email: email,
      phone: phone,
      notes: FirestoreContactMapper._optionalString(data, 'notes'),
      ownerId: FirestoreContactMapper._optionalString(data, 'ownerId'),
      isArchived: FirestoreContactMapper._requiredBool(data, 'isArchived'),
      createdByUserId: FirestoreContactMapper._requiredString(
        data,
        'createdByUserId',
      ),
      updatedByUserId: FirestoreContactMapper._requiredString(
        data,
        'updatedByUserId',
      ),
      createdAt: FirestoreContactMapper._requiredTimestamp(data, 'createdAt'),
      updatedAt: FirestoreContactMapper._requiredTimestamp(data, 'updatedAt'),
    );
  }

  final String fullName;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? notes;
  final String? ownerId;
  final bool isArchived;
  final String createdByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

final class _NormalizedInput {
  const _NormalizedInput({
    required this.fullName,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.notes,
    required this.ownerId,
  });

  factory _NormalizedInput.fromInput(ContactInput input) {
    final email = FirestoreContactMapper._normalizedOptional(input.email);
    final phone = FirestoreContactMapper._normalizedOptional(input.phone);

    if (email == null && phone == null) {
      throw const FormatException(
        'A contact requires an email address or phone number.',
      );
    }

    return _NormalizedInput(
      fullName: FirestoreContactMapper._normalizedRequired(
        input.fullName,
        'fullName',
      ),
      companyName: FirestoreContactMapper._normalizedOptional(
        input.companyName,
      ),
      email: email,
      phone: phone,
      notes: FirestoreContactMapper._normalizedOptional(input.notes),
      ownerId: FirestoreContactMapper._normalizedOptional(input.ownerId),
    );
  }

  final String fullName;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? notes;
  final String? ownerId;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'fullName': fullName,
      'companyName': companyName,
      'email': email,
      'phone': phone,
      'notes': notes,
      'ownerId': ownerId,
    };
  }
}
