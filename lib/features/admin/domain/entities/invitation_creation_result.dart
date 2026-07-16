import 'package:equatable/equatable.dart';

/// Firebase only confirms whether it accepted the password-reset email request.
/// It does not confirm inbox delivery or that the recipient opened the email.
enum InvitationEmailRequestResult { accepted, failed }

final class InvitationCreationResult extends Equatable {
  const InvitationCreationResult({
    required this.invitationId,
    required this.email,
    required this.expiresAt,
    required this.emailRequestStatus,
  });

  final String invitationId;
  final String email;
  final DateTime expiresAt;
  final InvitationEmailRequestResult emailRequestStatus;

  factory InvitationCreationResult.fromCallableData(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Invalid invitation response.');
    }

    final invitationId = _requiredString(value, 'invitationId');
    final email = _requiredString(value, 'email');
    final status = _requiredString(value, 'status');
    final emailRequestStatus = _requiredString(value, 'emailRequestStatus');
    final expiresAtMillis = value['expiresAtMillis'];

    if (status != 'pending' || expiresAtMillis is! int) {
      throw const FormatException('Invalid invitation response.');
    }

    return InvitationCreationResult(
      invitationId: invitationId,
      email: email,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtMillis),
      emailRequestStatus: switch (emailRequestStatus) {
        'accepted' => InvitationEmailRequestResult.accepted,
        'failed' => InvitationEmailRequestResult.failed,
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
  List<Object> get props => [
    invitationId,
    email,
    expiresAt,
    emailRequestStatus,
  ];
}
