import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_actions/contact_actions_cubit.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository repository;

  setUp(() {
    repository = _MockContactRepository();
  });

  test('converts the expected lead and emits success', () async {
    when(
      () => repository.convertLead(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'user-one',
      ),
    ).thenAnswer((_) async {});
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);

    await cubit.convertLead();

    verify(
      () => repository.convertLead(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'user-one',
      ),
    ).called(1);
    expect(cubit.state.status, ContactActionStatus.conversionSuccess);
  });

  test('archives the expected contact and emits success', () async {
    when(
      () => repository.archiveContact(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'user-one',
      ),
    ).thenAnswer((_) async {});
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);

    await cubit.archiveContact();

    verify(
      () => repository.archiveContact(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'user-one',
      ),
    ).called(1);
    expect(cubit.state.status, ContactActionStatus.archiveSuccess);
  });

  test('preserves typed action failures', () async {
    when(
      () => repository.convertLead(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenThrow(const ContactFailure(ContactFailureCode.permissionDenied));
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);

    await cubit.convertLead();

    expect(cubit.state.status, ContactActionStatus.failure);
    expect(
      cubit.state.failure,
      const ContactFailure(ContactFailureCode.permissionDenied),
    );
  });

  test('ignores duplicate actions while one is pending', () async {
    final completer = Completer<void>();
    when(
      () => repository.convertLead(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) => completer.future);
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);

    final conversion = cubit.convertLead();
    await Future<void>.delayed(Duration.zero);
    await cubit.archiveContact();

    verify(
      () => repository.convertLead(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'user-one',
      ),
    ).called(1);
    verifyNever(
      () => repository.archiveContact(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    );

    completer.complete();
    await conversion;
  });
}

ContactActionsCubit _buildCubit(ContactRepository repository) {
  return ContactActionsCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    contactId: 'contact-one',
    actorUserId: 'user-one',
  );
}
