import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/sales/presentation/cubit/sales_dashboard/sales_dashboard_cubit.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository repository;
  late StreamController<List<CrmContact>> controller;

  setUpAll(() {
    registerFallbackValue(const OwnedContactAccess('fallback'));
  });

  setUp(() {
    repository = _MockContactRepository();
    controller = StreamController<List<CrmContact>>.broadcast();
    when(
      () => repository.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => controller.stream);
  });

  tearDown(() => controller.close());

  test('loads only contacts owned by the sales representative', () async {
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);
    await _flush();

    controller.add(<CrmContact>[_newLead, _proposalLead, _lostLead, _client]);
    await _flush();

    verify(
      () => repository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: const OwnedContactAccess('sales-user'),
      ),
    ).called(1);
    expect(cubit.state.status, SalesDashboardStatus.success);
    expect(cubit.state.leads.length, 3);
    expect(cubit.state.clientCount, 1);
    expect(cubit.state.pipelineCount, 2);
    expect(cubit.state.countStage(LeadStage.proposal), 1);
    expect(cubit.state.recentContacts.length, 3);
  });

  test('preserves typed failures and retries the stream', () async {
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);
    await _flush();

    controller.addError(
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );
    await _flush();
    expect(
      cubit.state.failure,
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );

    await cubit.load();
    verify(
      () => repository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: const OwnedContactAccess('sales-user'),
      ),
    ).called(2);
  });

  test('maps unexpected stream errors to unknown', () async {
    final cubit = _buildCubit(repository);
    addTearDown(cubit.close);
    await _flush();

    controller.addError(StateError('unexpected'));
    await _flush();

    expect(
      cubit.state.failure,
      const ContactFailure(ContactFailureCode.unknown),
    );
  });
}

SalesDashboardCubit _buildCubit(ContactRepository repository) {
  return SalesDashboardCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    ownerId: 'sales-user',
  );
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _time = DateTime.utc(2026);

Lead _lead(String id, LeadStage stage) => Lead(
  id: id,
  workspaceId: 'workspace-one',
  fullName: id,
  companyName: null,
  email: '$id@example.com',
  phone: null,
  notes: null,
  ownerId: 'sales-user',
  stage: stage,
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _time,
  updatedAt: _time,
);

final _newLead = _lead('New lead', LeadStage.newLead);
final _proposalLead = _lead('Proposal lead', LeadStage.proposal);
final _lostLead = _lead('Lost lead', LeadStage.lost);
final _client = ClientContact(
  id: 'Client contact',
  workspaceId: 'workspace-one',
  fullName: 'Client contact',
  companyName: null,
  email: 'client@example.com',
  phone: null,
  notes: null,
  ownerId: 'sales-user',
  isArchived: false,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _time,
  updatedAt: _time,
  convertedAt: _time,
  convertedByUserId: 'sales-user',
);
