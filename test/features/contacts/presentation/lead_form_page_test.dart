import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/lead_form/lead_form_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/lead_form_page.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

final class _MockSalesAssigneeRepository extends Mock
    implements SalesAssigneeRepository {}

void main() {
  late ContactRepository contactRepository;
  late SalesAssigneeRepository salesAssigneeRepository;

  setUpAll(() {
    registerFallbackValue(
      const LeadInput(
        fullName: 'Fallback',
        companyName: null,
        email: 'fallback@example.com',
        phone: null,
        notes: null,
        ownerId: null,
        stage: LeadStage.newLead,
      ),
    );
  });

  setUp(() {
    contactRepository = _MockContactRepository();
    salesAssigneeRepository = _MockSalesAssigneeRepository();
  });

  testWidgets('validates the required name and contact method', (tester) async {
    final cubit = _salesCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, canAssignOwner: false);
    await tester.tap(find.widgetWithText(FilledButton, 'Create lead'));
    await tester.pump();

    expect(find.text('Enter the lead’s name.'), findsOneWidget);
    expect(
      find.text('Enter an email address or phone number.'),
      findsOneWidget,
    );
    verifyNever(
      () => contactRepository.createLead(
        workspaceId: any(named: 'workspaceId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    );
  });

  testWidgets('shows automatic ownership for sales representatives', (
    tester,
  ) async {
    final cubit = _salesCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, canAssignOwner: false);

    expect(find.text('Assigned to you'), findsOneWidget);
    expect(find.text('Assigned sales representative'), findsNothing);
    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('shows active assignees and allows stage selection for admins', (
    tester,
  ) async {
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer((_) => Stream.value(const <SalesAssignee>[_assignee]));
    final cubit = LeadFormCubit(
      contactRepository: contactRepository,
      salesAssigneeRepository: salesAssigneeRepository,
      workspaceId: 'workspace-one',
      actorUserId: 'admin-user',
      requiresAssigneeDirectory: true,
    );
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, canAssignOwner: true);
    await tester.pump();

    expect(find.text('Assigned sales representative'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);

    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    expect(find.text('Amit Sales (sales@example.com)'), findsOneWidget);
    await tester.tap(find.text('Amit Sales (sales@example.com)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qualified').last);
    await tester.pump();
    final stageDropdown = tester.widget<DropdownButton<LeadStage>>(
      find.byType(DropdownButton<LeadStage>),
    );
    expect(stageDropdown.value, LeadStage.qualified);
  });

  testWidgets('keeps the form usable when the assignee directory fails', (
    tester,
  ) async {
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer(
      (_) => Stream.error(const ContactFailure(ContactFailureCode.invalidData)),
    );
    final cubit = LeadFormCubit(
      contactRepository: contactRepository,
      salesAssigneeRepository: salesAssigneeRepository,
      workspaceId: 'workspace-one',
      actorUserId: 'admin-user',
      requiresAssigneeDirectory: true,
    );
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, canAssignOwner: true);

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('New lead'), findsOneWidget);
    expect(
      find.text('A sales membership is missing required profile information.'),
      findsOneWidget,
    );
    expect(
      find.text('You can still create this lead unassigned.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);

    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create lead'),
    );
    expect(createButton.onPressed, isNotNull);
  });

  testWidgets('explains when a lead save is waiting for Firestore', (
    tester,
  ) async {
    final completion = Completer<String>();
    when(
      () => contactRepository.createLead(
        workspaceId: any(named: 'workspaceId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) => completion.future);
    final cubit = LeadFormCubit(
      contactRepository: contactRepository,
      salesAssigneeRepository: salesAssigneeRepository,
      workspaceId: 'workspace-one',
      actorUserId: 'sales-user',
      requiresAssigneeDirectory: false,
      fixedOwnerId: 'sales-user',
      syncWaitThreshold: Duration.zero,
    );
    addTearDown(cubit.close);

    await _pumpForm(tester, cubit: cubit, canAssignOwner: false);
    await tester.enterText(find.byType(TextFormField).at(0), 'Asha Lead');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'asha@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create lead'));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Still saving this lead'), findsOneWidget);
    expect(
      find.textContaining('Waiting for Firestore to confirm the save.'),
      findsOneWidget,
    );
    expect(find.text('Back to Leads'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

  });
}

LeadFormCubit _salesCubit(
  ContactRepository contactRepository,
  SalesAssigneeRepository salesAssigneeRepository,
) {
  return LeadFormCubit(
    contactRepository: contactRepository,
    salesAssigneeRepository: salesAssigneeRepository,
    workspaceId: 'workspace-one',
    actorUserId: 'sales-user',
    requiresAssigneeDirectory: false,
    fixedOwnerId: 'sales-user',
  );
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required LeadFormCubit cubit,
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
          child: LeadFormPage(canAssignOwner: canAssignOwner),
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
