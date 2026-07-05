import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_edit/contact_edit_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_edit_page.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

final class _MockAssigneeRepository extends Mock
    implements SalesAssigneeRepository {}

void main() {
  late ContactRepository contacts;
  late SalesAssigneeRepository assignees;

  setUp(() {
    contacts = _MockContactRepository();
    assignees = _MockAssigneeRepository();
  });

  testWidgets('prefills a sales lead form and locks ownership', (tester) async {
    _stubContact(contacts, _lead);
    final cubit = _salesCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _pump(tester, cubit, canAssignOwner: false);

    expect(find.text('Edit lead'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Asha Lead'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Northstar'), findsOneWidget);
    expect(find.text('Qualified'), findsOneWidget);
    expect(find.text('Assigned to you'), findsOneWidget);
  });

  testWidgets('client form omits lead stage and supports admin assignment', (
    tester,
  ) async {
    _stubContact(contacts, _client);
    when(
      () => assignees.watchActiveSalesAssignees(workspaceId: 'workspace-one'),
    ).thenAnswer((_) => Stream.value(const [_assignee]));
    final cubit = _adminCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _pump(tester, cubit, canAssignOwner: true);

    expect(find.text('Edit client'), findsOneWidget);
    expect(find.text('Stage'), findsNothing);
    expect(find.text('Assigned sales representative'), findsOneWidget);
    expect(find.text('Amit Sales (sales@example.com)'), findsOneWidget);
  });

  testWidgets('validates required fields before saving', (tester) async {
    _stubContact(contacts, _lead);
    final cubit = _salesCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _pump(tester, cubit, canAssignOwner: false);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(2), '');
    await tester.enterText(fields.at(3), '');
    final saveButton = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Enter the contact’s name.'), findsOneWidget);
    expect(
      find.text('Enter an email address or phone number.'),
      findsOneWidget,
    );
  });
}

void _stubContact(ContactRepository repository, CrmContact contact) {
  when(
    () => repository.watchContact(
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
    ),
  ).thenAnswer((_) => Stream.value(contact));
}

ContactEditCubit _salesCubit(
  ContactRepository contacts,
  SalesAssigneeRepository assignees,
) => ContactEditCubit(
  contactRepository: contacts,
  salesAssigneeRepository: assignees,
  workspaceId: 'workspace-one',
  contactId: 'contact-one',
  actorUserId: 'sales-user',
  requiresAssigneeDirectory: false,
  fixedOwnerId: 'sales-user',
);

ContactEditCubit _adminCubit(
  ContactRepository contacts,
  SalesAssigneeRepository assignees,
) => ContactEditCubit(
  contactRepository: contacts,
  salesAssigneeRepository: assignees,
  workspaceId: 'workspace-one',
  contactId: 'contact-one',
  actorUserId: 'admin-user',
  requiresAssigneeDirectory: true,
);

Future<void> _pump(
  WidgetTester tester,
  ContactEditCubit cubit, {
  required bool canAssignOwner,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: ContactEditPage(canAssignOwner: canAssignOwner),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

const _assignee = SalesAssignee(
  userId: 'sales-user',
  workspaceId: 'workspace-one',
  displayName: 'Amit Sales',
  email: 'sales@example.com',
);
final _time = DateTime.utc(2026);
final _lead = Lead(
  id: 'contact-one',
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
  createdAt: _time,
  updatedAt: _time,
);
final _client = ClientContact(
  id: 'contact-one',
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
  createdAt: _time,
  updatedAt: _time,
  convertedAt: _time,
  convertedByUserId: 'sales-user',
);
