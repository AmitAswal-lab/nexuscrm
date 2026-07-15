import 'package:equatable/equatable.dart';

enum InvitationEmailDeliveryStatus { sent, failed }

final class InvitationCreationResult extends Equatable {
  const InvitationCreationResult({
    required this.invitationId,
    required this.email,
    required this.expiresAt,
    required this.deliveryStatus,
  });

  final String invitationId;
  final String email;
  final DateTime expiresAt;
  final InvitationEmailDeliveryStatus deliveryStatus;

  factory InvitationCreationResult.fromCallableData(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Invalid invitation response.');
    }

    final invitationId = _requiredString(value, 'invitationId');
    final email = _requiredString(value, 'email');
    final status = _requiredString(value, 'status');
    final deliveryStatus = _requiredString(value, 'deliveryStatus');
    final expiresAtMillis = value['expiresAtMillis'];

    if (status != 'pending' || expiresAtMillis is! int) {
      throw const FormatException('Invalid invitation response.');
    }

    return InvitationCreationResult(
      invitationId: invitationId,
      email: email,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
      deliveryStatus: switch (deliveryStatus) {
        'sent' => InvitationEmailDeliveryStatus.sent,
        'failed' => InvitationEmailDeliveryStatus.failed,
        _ => throw const FormatException('Invalid invitation response.'),
      },
    );
  }

  static String _requiredString(Map<Object?, Object?> value, String key) {
    final field = value[key];
    if (field is! String || field.trim().isEmpty) {
      throw const FormatException('Invalid invitation response.');
    }
    return field;
  }

  @override
  List<Object> get props => [invitationId, email, expiresAt, deliveryStatus];
}
