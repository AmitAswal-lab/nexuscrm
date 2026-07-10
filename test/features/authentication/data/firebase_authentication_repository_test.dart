import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/authentication/data/repositories/firebase_authentication_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';

final class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

final class _MockUser extends Mock implements User {}

final class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  late FirebaseAuth firebaseAuth;
  late FirebaseAuthenticationRepository repository;

  setUp(() {
    firebaseAuth = _MockFirebaseAuth();
    repository = FirebaseAuthenticationRepository(firebaseAuth);
  });

  group('watchAuthUser', () {
    test('maps Firebase users and signed-out events', () async {
      final user = _MockUser();
      when(() => user.uid).thenReturn('user-one');
      when(() => user.email).thenReturn('admin@example.com');
      when(() => user.displayName).thenReturn('  Amit  ');
      when(
        () => firebaseAuth.idTokenChanges(),
      ).thenAnswer((_) => Stream.value(user));

      await expectLater(
        repository.watchAuthUser(),
        emits(
          const AuthUser(
            id: 'user-one',
            email: 'admin@example.com',
            displayName: 'Amit',
          ),
        ),
      );

      when(
        () => firebaseAuth.idTokenChanges(),
      ).thenAnswer((_) => Stream<User?>.value(null));
      await expectLater(repository.watchAuthUser(), emits(isNull));
    });

    test('rejects Firebase users without an email', () async {
      final user = _MockUser();
      when(() => user.email).thenReturn(null);
      when(
        () => firebaseAuth.idTokenChanges(),
      ).thenAnswer((_) => Stream.value(user));

      await expectLater(
        repository.watchAuthUser(),
        emitsError(
          const AuthenticationFailure(AuthenticationFailureCode.invalidData),
        ),
      );
    });
  });

  group('signIn', () {
    test('trims the email before forwarding credentials', () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => _MockUserCredential());

      await repository.signIn(
        email: '  admin@example.com  ',
        password: 'password',
      );

      verify(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'admin@example.com',
          password: 'password',
        ),
      ).called(1);
    });

    for (final testCase in <(String, AuthenticationFailureCode)>[
      ('invalid-credential', AuthenticationFailureCode.invalidCredentials),
      ('invalid-email', AuthenticationFailureCode.invalidEmail),
      ('user-disabled', AuthenticationFailureCode.userDisabled),
      ('too-many-requests', AuthenticationFailureCode.tooManyRequests),
      ('network-request-failed', AuthenticationFailureCode.networkUnavailable),
      ('operation-not-allowed', AuthenticationFailureCode.operationNotAllowed),
      ('unexpected-code', AuthenticationFailureCode.unknown),
    ]) {
      test('maps ${testCase.$1} to ${testCase.$2.name}', () async {
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: testCase.$1));

        expect(
          repository.signIn(email: 'admin@example.com', password: 'password'),
          throwsA(AuthenticationFailure(testCase.$2)),
        );
      });
    }
  });

  test('signOut maps Firebase failures', () async {
    when(
      () => firebaseAuth.signOut(),
    ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

    expect(
      repository.signOut(),
      throwsA(
        const AuthenticationFailure(
          AuthenticationFailureCode.networkUnavailable,
        ),
      ),
    );
  });
}
