import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_archive_filter.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/archived_contacts/archived_contacts_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/archived_contacts_page.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;

  setUpAll(() {
    registerFallbackValue(const WorkspaceContactAccess());
  });

  setUp(() {
    contactRepository = _MockContactRepository();
  });

  test('asks only for archived contacts', () async {
    _stubArchived(contactRepository, <CrmContact>[_archivedLead]);

    final cubit = _cubit(contactRepository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.status, ArchivedContactsStatus.success);
    expect(cubit.state.contacts, <CrmContact>[_archivedLead]);
    verify(
      () => contactRepository.watchContacts(
        workspaceId: 'workspace-one',
        accessScope: any(named: 'accessScope'),
        archiveFilter: ContactArchiveFilter.archived,
      ),
    ).called(1);
  });

  test('restores a contact through the repository', () async {
    _stubArchived(contactRepository, <CrmContact>[_archivedLead]);
    when(
      () => contactRepository.restoreContact(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) async {});

    final cubit = _cubit(contactRepository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await cubit.restore('lead-one');

    verify(
      () => contactRepository.restoreContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).called(1);
    expect(cubit.state.restoringContactId, isNull);
    expect(cubit.state.actionFailure, isNull);
  });

  test('reports a restore failure without clearing the list', () async {
    _stubArchived(contactRepository, <CrmContact>[_archivedLead]);
    when(
      () => contactRepository.restoreContact(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenThrow(const ContactFailure(ContactFailureCode.permissionDenied));

    final cubit = _cubit(contactRepository);
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);
    await cubit.restore('lead-one');

    expect(
      cubit.state.actionFailure,
      const ContactFailure(ContactFailureCode.permissionDenied),
    );
    expect(cubit.state.contacts, <CrmContact>[_archivedLead]);
    expect(cubit.state.restoringContactId, isNull);
  });

  testWidgets('lists archived contacts and restores one', (tester) async {
    _stubArchived(contactRepository, <CrmContact>[_archivedLead]);
    when(
      () => contactRepository.restoreContact(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    ).thenAnswer((_) async {});

    await _pumpPage(tester, contactRepository);

    expect(find.text('Archived contacts'), findsOneWidget);
    expect(find.text('Asha Lead'), findsOneWidget);
    expect(find.text('Lead · Northstar'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
    await tester.pumpAndSettle();

    verify(
      () => contactRepository.restoreContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).called(1);
  });

  testWidgets('shows an empty state when nothing is archived', (tester) async {
    _stubArchived(contactRepository, const <CrmContact>[]);

    await _pumpPage(tester, contactRepository);

    expect(find.text('No archived contacts.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Restore'), findsNothing);
  });
}

void _stubArchived(ContactRepository repository, List<CrmContact> contacts) {
  when(
    () => repository.watchContacts(
      workspaceId: any(named: 'workspaceId'),
      accessScope: any(named: 'accessScope'),
      archiveFilter: ContactArchiveFilter.archived,
    ),
  ).thenAnswer((_) => Stream.value(contacts));
}

ArchivedContactsCubit _cubit(ContactRepository repository) {
  return ArchivedContactsCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    accessScope: const WorkspaceContactAccess(),
    actorUserId: 'admin-user',
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  ContactRepository repository,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => BlocProvider(
          create: (_) => _cubit(repository),
          child: const Scaffold(body: ArchivedContactsPage()),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

final _timestamp = DateTime.utc(2026);

final _archivedLead = Lead(
  id: 'lead-one',
  workspaceId: 'workspace-one',
  fullName: 'Asha Lead',
  companyName: 'Northstar',
  email: 'asha@example.com',
  phone: null,
  notes: null,
  ownerId: 'sales-user',
  stage: LeadStage.qualified,
  isArchived: true,
  createdByUserId: 'sales-user',
  updatedByUserId: 'sales-user',
  createdAt: _timestamp,
  updatedAt: _timestamp,
);
