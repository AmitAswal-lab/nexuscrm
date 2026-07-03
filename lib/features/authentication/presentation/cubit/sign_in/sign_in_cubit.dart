import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';
import 'package:nexuscrm/features/authentication/domain/repositories/authentication_repository.dart';

part 'sign_in_state.dart';

final class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._authenticationRepository) : super(const SignInState());

  final AuthenticationRepository _authenticationRepository;

  Future<void> submit({required String email, required String password}) async {
    if (state.status == SignInStatus.submitting) {
      return;
    }

    emit(const SignInState(status: SignInStatus.submitting));

    try {
      await _authenticationRepository.signIn(email: email, password: password);

      if (!isClosed) {
        emit(const SignInState(status: SignInStatus.success));
      }
    } on AuthenticationFailure catch (failure) {
      if (!isClosed) {
        emit(SignInState(status: SignInStatus.failure, failure: failure));
      }
    } on Object {
      if (!isClosed) {
        emit(
          const SignInState(
            status: SignInStatus.failure,
            failure: AuthenticationFailure(AuthenticationFailureCode.unknown),
          ),
        );
      }
    }
  }

  void clearFailure() {
    if (state.status == SignInStatus.failure) {
      emit(const SignInState());
    }
  }
}
