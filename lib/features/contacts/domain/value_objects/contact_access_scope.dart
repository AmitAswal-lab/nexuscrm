import 'package:equatable/equatable.dart';

sealed class ContactAccessScope extends Equatable {
  const ContactAccessScope();
}

final class WorkspaceContactAccess extends ContactAccessScope {
  const WorkspaceContactAccess();

  @override
  List<Object?> get props => [];
}

final class OwnedContactAccess extends ContactAccessScope {
  const OwnedContactAccess(this.ownerId);

  final String ownerId;

  @override
  List<Object> get props => [ownerId];
}
