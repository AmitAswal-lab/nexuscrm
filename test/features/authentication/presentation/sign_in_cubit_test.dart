import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:nexuscrm/features/authentication/presentation/cubit/sign_in/sign_in_cubit.dart';

final class _MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

void main() {
  late AuthenticationRepository authenticationRepository;

  setUp(() {
    authenticationRepository = _MockAuthenticationRepository();
  });

  blocTest<SignInCubit, SignInState>(
    'emits submitting then success',
    setUp: () {
      when(
        () => authenticationRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});
    },
    build: () => SignInCubit(authenticationRepository),
    act: (cubit) =>
        cubit.submit(email: 'admin@example.com', password: 'password'),
    expect: () => const <SignInState>[
      SignInState(status: SignInStatus.submitting),
      SignInState(status: SignInStatus.success),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'preserves typed authentication failures',
    setUp: () {
      when(
        () => authenticationRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthenticationFailure(
          AuthenticationFailureCode.invalidCredentials,
        ),
      );
    },
    build: () => SignInCubit(authenticationRepository),
    act: (cubit) => cubit.submit(email: 'admin@example.com', password: 'wrong'),
    expect: () => const <SignInState>[
      SignInState(status: SignInStatus.submitting),
      SignInState(
        status: SignInStatus.failure,
        failure: AuthenticationFailure(
          AuthenticationFailureCode.invalidCredentials,
        ),
      ),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'maps unexpected errors to an unknown failure',
    setUp: () {
      when(
        () => authenticationRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(StateError('unexpected'));
    },
    build: () => SignInCubit(authenticationRepository),
    act: (cubit) =>
        cubit.submit(email: 'admin@example.com', password: 'password'),
    expect: () => const <SignInState>[
      SignInState(status: SignInStatus.submitting),
      SignInState(
        status: SignInStatus.failure,
        failure: AuthenticationFailure(AuthenticationFailureCode.unknown),
      ),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'ignores duplicate submissions while one is pending',
    setUp: () {
      final completer = Completer<void>();
      when(
        () => authenticationRepository.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => completer.future);
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
    },
    build: () => SignInCubit(authenticationRepository),
    act: (cubit) async {
      final first = cubit.submit(
        email: 'admin@example.com',
        password: 'password',
      );
      final second = cubit.submit(
        email: 'admin@example.com',
        password: 'password',
      );

      verify(
        () => authenticationRepository.signIn(
          email: 'admin@example.com',
          password: 'password',
        ),
      ).called(1);

      // Closing the cubit in blocTest safely completes the pending submission.
      unawaited(first);
      await second;
    },
    expect: () => const <SignInState>[
      SignInState(status: SignInStatus.submitting),
    ],
  );

  blocTest<SignInCubit, SignInState>(
    'clears an existing failure',
    build: () => SignInCubit(authenticationRepository),
    seed: () => const SignInState(
      status: SignInStatus.failure,
      failure: AuthenticationFailure(
        AuthenticationFailureCode.invalidCredentials,
      ),
    ),
    act: (cubit) => cubit.clearFailure(),
    expect: () => const <SignInState>[SignInState()],
  );
}
