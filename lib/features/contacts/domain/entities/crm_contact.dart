import 'package:equatable/equatable.dart';

enum ContactKind { lead, client }

enum LeadStage { newLead, contacted, qualified, proposal, lost }

sealed class CrmContact extends Equatable {
  const CrmContact({
    required this.id,
    required this.workspaceId,
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

  final String id;
  final String workspaceId;
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

  ContactKind get kind;

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    kind,
    fullName,
    companyName,
    email,
    phone,
    notes,
    ownerId,
    isArchived,
    createdByUserId,
    updatedByUserId,
    createdAt,
    updatedAt,
  ];
}

final class Lead extends CrmContact {
  const Lead({
    required super.id,
    required super.workspaceId,
    required super.fullName,
    required super.companyName,
    required super.email,
    required super.phone,
    required super.notes,
    required super.ownerId,
    required this.stage,
    required super.isArchived,
    required super.createdByUserId,
    required super.updatedByUserId,
    required super.createdAt,
    required super.updatedAt,
  });

  final LeadStage stage;

  @override
  ContactKind get kind => ContactKind.lead;

  @override
  List<Object?> get props => [...super.props, stage];
}

final class ClientContact extends CrmContact {
  const ClientContact({
    required super.id,
    required super.workspaceId,
    required super.fullName,
    required super.companyName,
    required super.email,
    required super.phone,
    required super.notes,
    required super.ownerId,
    required super.isArchived,
    required super.createdByUserId,
    required super.updatedByUserId,
    required super.createdAt,
    required super.updatedAt,
    required this.convertedAt,
    required this.convertedByUserId,
  });

  final DateTime convertedAt;
  final String convertedByUserId;

  @override
  ContactKind get kind => ContactKind.client;

  @override
  List<Object?> get props => [...super.props, convertedAt, convertedByUserId];
}
