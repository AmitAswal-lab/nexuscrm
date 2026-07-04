import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';

sealed class ContactInput extends Equatable {
  const ContactInput({
    required this.fullName,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.notes,
    required this.ownerId,
  });

  final String fullName;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? notes;
  final String? ownerId;

  @override
  List<Object?> get props => [
    fullName,
    companyName,
    email,
    phone,
    notes,
    ownerId,
  ];
}

final class LeadInput extends ContactInput {
  const LeadInput({
    required super.fullName,
    required super.companyName,
    required super.email,
    required super.phone,
    required super.notes,
    required super.ownerId,
    required this.stage,
  });

  final LeadStage stage;

  @override
  List<Object?> get props => [...super.props, stage];
}

final class ClientInput extends ContactInput {
  const ClientInput({
    required super.fullName,
    required super.companyName,
    required super.email,
    required super.phone,
    required super.notes,
    required super.ownerId,
  });
}
