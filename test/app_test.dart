import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/membership_repository.dart';

import 'helpers/empty_contact_repository.dart';

void main() {
  testWidgets('renders the signed-out application foundation', (tester) async {
    await tester.pumpWidget(
      NexusCrmApp(
        authenticationRepository: _SignedOutAuthenticationRepository(),
        membershipRepository: _EmptyMembershipRepository(),
        contactRepository: const EmptyContactRepository(),
        salesAssigneeRepository: const EmptySalesAssigneeRepository(),
        taskRepository: const EmptyTaskRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'Nexus CRM');
    expect(find.text('Nexus CRM'), findsOneWidget);
    expect(find.text('Sign in to your workspace'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
  });
}

final class _SignedOutAuthenticationRepository
    implements AuthenticationRepository {
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Stream<AuthUser?> watchAuthUser() => Stream.value(null);
}

final class _EmptyMembershipRepository implements MembershipRepository {
  @override
  Stream<List<WorkspaceMembership>> watchMemberships({required String userId}) {
    return const Stream.empty();
  }
}
