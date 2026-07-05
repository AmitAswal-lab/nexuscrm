import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;
  late StreamController<CrmContact?> contactController;

  setUp(() {
    contactRepository = _MockContactRepository();
    contactController = StreamController<CrmContact?>.broadcast();
    when(
      () => contactRepository.watchContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
      ),
    ).thenAnswer((_) => contactController.stream);
  });

  tearDown(() async {
    await contactController.close();
  });

  test('emits contact updates from the live subscription', () async {
    final cubit = _buildCubit(contactRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    contactController.add(_lead);
    await _flushAsync();
    expect(
      cubit.state,
      ContactDetailState(status: ContactDetailStatus.success, contact: _lead),
    );

    contactController.add(_client);
    await _flushAsync();
    expect(cubit.state.contact, _client);
  });

  test('emits not found when the contact no longer exists', () async {
    final cubit = _buildCubit(contactRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    contactController.add(null);
    await _flushAsync();

    expect(
      cubit.state,
      const ContactDetailState(status: ContactDetailStatus.notFound),
    );
  });

  test('preserves typed failures', () async {
    final cubit = _buildCubit(contactRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    contactController.addError(
      const ContactFailure(ContactFailureCode.permissionDenied),
    );
    await _flushAsync();

    expect(
      cubit.state,
      const ContactDetailState(
        status: ContactDetailStatus.failure,
        failure: ContactFailure(ContactFailureCode.permissionDenied),
      ),
    );
  });

  test('maps unexpected errors to an unknown failure', () async {
    final cubit = _buildCubit(contactRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    contactController.addError(StateError('unexpected'));
    await _flushAsync();

    expect(
      cubit.state.failure,
      const ContactFailure(ContactFailureCode.unknown),
    );
  });

  test('retries the contact subscription', () async {
    final cubit = _buildCubit(contactRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    contactController.addError(
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );
    await _flushAsync();
    await cubit.load();

    expect(cubit.state, const ContactDetailState());
    verify(
      () => contactRepository.watchContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
      ),
    ).called(2);
  });
}

ContactDetailCubit _buildCubit(ContactRepository repository) {
  return ContactDetailCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    contactId: 'lead-one',
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _timestamp = DateTime.utc(2026);

final _lead = Lead(
  id: 'lead-one',
  workspaceId: 'workspace-one',
  fullName: 'Asha Lead',
  companyName: 'Northstar',
  email: 'asha@example.com',
  phone: null,
  notes: 'Ready to talk.',
  ownerId: 'sales-user',
  stage: LeadStage.qualified,
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _client = ClientContact(
  id: 'lead-one',
  workspaceId: 'workspace-one',
  fullName: 'Asha Lead',
  companyName: 'Northstar',
  email: 'asha@example.com',
  phone: null,
  notes: 'Ready to talk.',
  ownerId: 'sales-user',
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _timestamp,
  updatedAt: _timestamp,
  convertedAt: _timestamp,
  convertedByUserId: 'sales-user',
);
