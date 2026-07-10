part of 'contact_actions_cubit.dart';

enum ContactActionStatus {
  idle,
  converting,
  conversionSuccess,
  archiving,
  archiveSuccess,
  failure,
}

final class ContactActionsState extends Equatable {
  const ContactActionsState({
    this.status = ContactActionStatus.idle,
    this.failure,
  });

  final ContactActionStatus status;
  final ContactFailure? failure;

  bool get isBusy =>
      status == ContactActionStatus.converting ||
      status == ContactActionStatus.archiving;

  @override
  List<Object?> get props => [status, failure];
}
