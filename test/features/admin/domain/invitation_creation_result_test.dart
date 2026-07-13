import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/invitation_creation_result.dart';

void main() {
  test('maps only the safe callable invitation response', () {
    final result = InvitationCreationResult.fromCallableData(<String, Object>{
      'invitationId': 'invitation-one',
      'email': 'rep@example.com',
      'status': 'pending',
      'expiresAtMillis': 1784548800000,
      'deliveryStatus': 'sent',
    });

    expect(result.invitationId, 'invitation-one');
    expect(result.email, 'rep@example.com');
    expect(result.deliveryStatus, InvitationDeliveryStatus.sent);
  });

  test('rejects responses containing an unsupported invitation state', () {
    expect(
      () => InvitationCreationResult.fromCallableData(<String, Object>{
        'invitationId': 'invitation-one',
        'email': 'rep@example.com',
        'status': 'active',
        'expiresAtMillis': 1784548800000,
        'deliveryStatus': 'sent',
      }),
      throwsFormatException,
    );
  });
}
