import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';

final class FirebaseAuthenticationRepository
    implements AuthenticationRepository {
  FirebaseAuthenticationRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthUser?> watchAuthUser() async* {
    try {
      await for (final user in _firebaseAuth.idTokenChanges()) {
        yield user == null ? null : _mapUser(user);
      }
    } on AuthenticationFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (error) {
      throw _mapFailure(error);
    }
  }

  static AuthUser _mapUser(User user) {
    final email = user.email;

    if (email == null || email.trim().isEmpty) {
      throw const AuthenticationFailure(AuthenticationFailureCode.invalidData);
    }

    final displayName = user.displayName?.trim();

    return AuthUser(
      id: user.uid,
      email: email,
      displayName: displayName == null || displayName.isEmpty
          ? null
          : displayName,
    );
  }

  static AuthenticationFailure _mapFailure(FirebaseAuthException error) {
    final code = switch (error.code) {
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => AuthenticationFailureCode.invalidCredentials,
      'invalid-email' => AuthenticationFailureCode.invalidEmail,
      'user-disabled' => AuthenticationFailureCode.userDisabled,
      'too-many-requests' => AuthenticationFailureCode.tooManyRequests,
      'network-request-failed' => AuthenticationFailureCode.networkUnavailable,
      'operation-not-allowed' => AuthenticationFailureCode.operationNotAllowed,
      _ => AuthenticationFailureCode.unknown,
    };

    return AuthenticationFailure(code);
  }
}
