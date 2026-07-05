import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/value_objects/contact_access_scope.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_list/contact_list_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_list_page.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;

  setUpAll(() {
    registerFallbackValue(const WorkspaceContactAccess());
  });

  setUp(() {
    contactRepository = _MockContactRepository();
  });

  testWidgets('renders an honest empty state', (tester) async {
    when(
      () => contactRepository.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => Stream.value(const <CrmContact>[]));

    await _pumpPage(tester, contactRepository);

    expect(find.text('Leads & clients'), findsOneWidget);
    expect(find.text('No leads or clients yet.'), findsOneWidget);
    expect(
      find.text('Lead creation will be added in the next workflow checkpoint.'),
      findsOneWidget,
    );
  });

  testWidgets('renders lead and client information and filters results', (
    tester,
  ) async {
    when(
      () => contactRepository.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => Stream.value(<CrmContact>[_lead, _client]));

    await _pumpPage(tester, contactRepository);

    expect(find.text('Asha Lead'), findsOneWidget);
    expect(find.text('Northstar'), findsOneWidget);
    expect(find.text('Qualified'), findsOneWidget);
    expect(find.text('Ravi Client'), findsOneWidget);
    expect(find.text('+91 90000 00000'), findsOneWidget);
    expect(find.text('Client'), findsOneWidget);

    await tester.tap(find.text('Clients'));
    await tester.pump();

    expect(find.text('Asha Lead'), findsNothing);
    expect(find.text('Ravi Client'), findsOneWidget);
  });

  testWidgets('shows a typed failure with an enabled retry action', (
    tester,
  ) async {
    final contactsController = StreamController<List<CrmContact>>.broadcast();
    addTearDown(contactsController.close);
    when(
      () => contactRepository.watchContacts(
        workspaceId: any(named: 'workspaceId'),
        accessScope: any(named: 'accessScope'),
        includeArchived: any(named: 'includeArchived'),
      ),
    ).thenAnswer((_) => contactsController.stream);

    await _pumpPage(tester, contactRepository);
    contactsController.addError(
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );
    await tester.pump();

    expect(
      find.text(
        'Contacts are unavailable. Check your connection and try again.',
      ),
      findsOneWidget,
    );

    final retryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Try again'),
    );
    expect(retryButton.onPressed, isNotNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  ContactRepository contactRepository,
) async {
  final cubit = ContactListCubit(
    contactRepository: contactRepository,
    workspaceId: 'workspace-one',
    accessScope: const WorkspaceContactAccess(),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: ContactListPage(
          title: 'Leads & clients',
          description: 'All active contacts in this workspace.',
          onCreateLead: () {},
          onOpenContact: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
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
