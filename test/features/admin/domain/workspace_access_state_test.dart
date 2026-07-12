import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/features/admin/domain/entities/workspace_invitation.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

void main() {
  test('membership transitions enforce the representative lifecycle', () {
    expect(
      MembershipStatus.invited.canTransitionTo(MembershipStatus.active),
      isTrue,
    );
    expect(
      MembershipStatus.active.canTransitionTo(MembershipStatus.suspended),
      isTrue,
    );
    expect(
      MembershipStatus.suspended.canTransitionTo(MembershipStatus.active),
      isTrue,
    );
    expect(
      MembershipStatus.revoked.canTransitionTo(MembershipStatus.active),
      isFalse,
    );
    expect(
      MembershipStatus.invited.canTransitionTo(MembershipStatus.suspended),
      isFalse,
    );
  });

  test(
    'invitations are single-use after acceptance, expiry, or revocation',
    () {
      expect(
        InvitationStatus.pending.canTransitionTo(InvitationStatus.accepted),
        isTrue,
      );
      expect(
        InvitationStatus.pending.canTransitionTo(InvitationStatus.expired),
        isTrue,
      );
      expect(
        InvitationStatus.pending.canTransitionTo(InvitationStatus.revoked),
        isTrue,
      );
      expect(
        InvitationStatus.accepted.canTransitionTo(InvitationStatus.pending),
        isFalse,
      );
      expect(
        InvitationStatus.expired.canTransitionTo(InvitationStatus.pending),
        isFalse,
      );
    },
  );
}
