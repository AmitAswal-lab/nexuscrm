import 'package:equatable/equatable.dart';
import 'package:nexuscrm/features/authentication/domain/entities/auth_user.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

final class AuthSession extends Equatable {
  const AuthSession({required this.user, required this.membership});

  final AuthUser user;
  final WorkspaceMembership membership;

  @override
  List<Object> get props => [user, membership];
}
