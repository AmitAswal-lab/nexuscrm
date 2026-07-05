import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_list/contact_list_cubit.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;
  late StreamController<List<CrmContact>> contactsController;

  setUpAll(() {
    registerFallbackValue(const WorkspaceContactAccess());
  });

  setUp(() {
    contactRepository = _MockContactRepository();
    contactsController = StreamController<List<CrmContact>>.broadcast();
    when(
      () => contactRepository.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => contactsController.stream);
  });

  tearDown(() async {
    await contactsController.close();
  });

  test('loads workspace contacts with the supplied admin scope', () async {
    final cubit = _buildCubit(
      contactRepository,
      const WorkspaceContactAccess(),
    );
    addTearDown(cubit.close);
    await _flushAsync();

    contactsController.add(<CrmContact>[_lead]);
    await _flushAsync();

    expect(
      cubit.state,
      ContactListState(
        status: ContactListStatus.success,
        contacts: <CrmContact>[_lead],
      ),
    );
    verify(
      () => contactRepository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: const WorkspaceContactAccess(),
      ),
    ).called(1);
  });

  test('uses the supplied owner scope and filters contacts locally', () async {
    final cubit = _buildCubit(
      contactRepository,
      const OwnedContactAccess('sales-user'),
    );
    addTearDown(cubit.close);
    await _flushAsync();

    contactsController.add(<CrmContact>[_lead, _client]);
    await _flushAsync();
    cubit.selectFilter(ContactListFilter.clients);

    expect(cubit.state.visibleContacts, <CrmContact>[_client]);
    verify(
      () => contactRepository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: const OwnedContactAccess('sales-user'),
      ),
    ).called(1);
  });

  test('preserves typed failures and retries the subscription', () async {
    final cubit = _buildCubit(
      contactRepository,
      const WorkspaceContactAccess(),
    );
    addTearDown(cubit.close);
    await _flushAsync();

    contactsController.addError(
      const ContactFailure(ContactFailureCode.permissionDenied),
    );
    await _flushAsync();

    expect(
      cubit.state,
      const ContactListState(
        status: ContactListStatus.failure,
        failure: ContactFailure(ContactFailureCode.permissionDenied),
      ),
    );

    await cubit.load();

    expect(cubit.state, const ContactListState());
    verify(
      () => contactRepository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: const WorkspaceContactAccess(),
      ),
    ).called(2);
  });

  test('maps unexpected stream errors to an unknown failure', () async {
    final cubit = _buildCubit(
      contactRepository,
      const WorkspaceContactAccess(),
    );
    addTearDown(cubit.close);
    await _flushAsync();

    contactsController.addError(StateError('unexpected'));
    await _flushAsync();

    expect(
      cubit.state,
      const ContactListState(
        status: ContactListStatus.failure,
        failure: ContactFailure(ContactFailureCode.unknown),
      ),
    );
  });
}

ContactListCubit _buildCubit(
  ContactRepository repository,
  ContactAccessScope accessScope,
) {
  return ContactListCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    accessScope: accessScope,
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
  notes: null,
  ownerId: 'sales-user',
  stage: LeadStage.qualified,
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);

final _client = ClientContact(
  id: 'client-one',
  workspaceId: 'workspace-one',
  fullName: 'Ravi Client',
  companyName: null,
  email: null,
  phone: '+91 90000 00000',
  notes: null,
  ownerId: 'sales-user',
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _timestamp,
  updatedAt: _timestamp,
  convertedAt: _timestamp,
  convertedByUserId: 'sales-user',
);
