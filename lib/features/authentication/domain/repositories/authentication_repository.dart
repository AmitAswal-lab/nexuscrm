import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';

abstract interface class AuthenticationRepository {
  Stream<AuthUser?> watchAuthUser();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
