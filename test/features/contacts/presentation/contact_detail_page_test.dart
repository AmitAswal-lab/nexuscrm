import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_actions/contact_actions_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_detail_page.dart';
import 'package:nexuscrm/features/tasks/domain/value_objects/task_access_scope.dart';

import '../../../helpers/empty_contact_repository.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;

  setUp(() {
    contactRepository = _MockContactRepository();
  });

  testWidgets('renders lead details for an admin', (tester) async {
    var editOpened = false;
    _stubContact(contactRepository, Stream.value(_lead));

    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
      onEdit: () => editOpened = true,
    );

    expect(find.text('Asha Lead'), findsOneWidget);
    expect(find.text('Lead · Qualified'), findsOneWidget);
    expect(find.text('Northstar'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('Ready to talk.'), findsOneWidget);
    expect(find.text('Assigned sales representative'), findsOneWidget);
    expect(find.text('1 Jan 2026'), findsOneWidget);
    expect(find.text('Convert to client'), findsOneWidget);
    expect(find.text('Archive contact'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    expect(editOpened, isTrue);
  });

  testWidgets('renders client history and sales assignment wording', (
    tester,
  ) async {
    _stubContact(contactRepository, Stream.value(_client));

    await _pumpDetail(tester, repository: contactRepository, isSalesView: true);

    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Assigned to you'), findsOneWidget);
    expect(find.text('Client history'), findsOneWidget);
    expect(find.text('Converted'), findsOneWidget);
    expect(find.text('Convert to client'), findsNothing);
    expect(find.text('Archive contact'), findsOneWidget);
  });

  testWidgets('renders a missing-contact state', (tester) async {
    _stubContact(contactRepository, Stream.value(null));

    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
    );

    expect(find.text('This contact is no longer available.'), findsOneWidget);
    expect(find.text('Back to contacts'), findsOneWidget);
  });

  testWidgets('renders typed failures with an enabled retry action', (
    tester,
  ) async {
    _stubContact(
      contactRepository,
      Stream<CrmContact?>.error(
        const ContactFailure(ContactFailureCode.networkUnavailable),
      ),
    );

    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
    );

    expect(
      find.text(
        'The contact is unavailable. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    final retryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Try again'),
    );
    expect(retryButton.onPressed, isNotNull);
    expect(find.text('Back to contacts'), findsOneWidget);
  });

  testWidgets('cancels conversion without calling the repository', (
    tester,
  ) async {
    _stubContact(contactRepository, Stream.value(_lead));
    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
    );

    final convertAction = find.text('Convert to client');
    await tester.ensureVisible(convertAction);
    await tester.pump();
    await tester.tap(convertAction);
    await tester.pumpAndSettle();
    expect(find.text('Convert lead to client?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(
      () => contactRepository.convertLead(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
      ),
    );
  });

  testWidgets('confirms conversion and shows success feedback', (tester) async {
    when(
      () => contactRepository.convertLead(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).thenAnswer((_) async {});
    _stubContact(contactRepository, Stream.value(_lead));
    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
    );

    final convertAction = find.text('Convert to client');
    await tester.ensureVisible(convertAction);
    await tester.pump();
    await tester.tap(convertAction);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Convert'));
    await tester.pump();
    await tester.pump();

    verify(
      () => contactRepository.convertLead(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).called(1);
    expect(find.text('Lead converted to a client.'), findsOneWidget);
  });

  testWidgets('returns to the contact list after archive', (tester) async {
    when(
      () => contactRepository.archiveContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).thenAnswer((_) async {});
    _stubContact(contactRepository, Stream.value(_lead));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('Contact list'))),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            return Scaffold(
              body: MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ContactDetailCubit(
                      contactRepository: contactRepository,
                      workspaceId: 'workspace-one',
                      contactId: 'lead-one',
                    ),
                  ),
                  BlocProvider(
                    create: (_) => ContactActionsCubit(
                      contactRepository: contactRepository,
                      workspaceId: 'workspace-one',
                      contactId: 'lead-one',
                      actorUserId: 'admin-user',
                    ),
                  ),
                ],
                child: ContactDetailPage(
                  isSalesView: false,
                  onEdit: () {},
                  onAddFollowUp: () {},
                  workspaceId: 'workspace-one',
                  taskAccessScope: const WorkspaceTaskAccess(),
                  taskRepository: const EmptyTaskRepository(),
                ),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    unawaited(router.push('/detail'));
    await tester.pumpAndSettle();

    final archiveAction = find.text('Archive contact');
    await tester.ensureVisible(archiveAction);
    await tester.pump();
    await tester.tap(archiveAction);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('Contact list'), findsOneWidget);
    verify(
      () => contactRepository.archiveContact(
        workspaceId: 'workspace-one',
        contactId: 'lead-one',
        actorUserId: 'admin-user',
      ),
    ).called(1);
  });
}

void _stubContact(ContactRepository repository, Stream<CrmContact?> stream) {
  when(
    () => repository.watchContact(
      workspaceId: 'workspace-one',
      contactId: 'lead-one',
    ),
  ).thenAnswer((_) => stream);
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required ContactRepository repository,
  required bool isSalesView,
  VoidCallback? onEdit,
}) async {
  final cubit = ContactDetailCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    contactId: 'lead-one',
  );
  final actionsCubit = ContactActionsCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    contactId: 'lead-one',
    actorUserId: 'admin-user',
  );
  addTearDown(cubit.close);
  addTearDown(actionsCubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: actionsCubit),
          ],
          child: ContactDetailPage(
            isSalesView: isSalesView,
            onEdit: onEdit ?? () {},
            onAddFollowUp: () {},
            workspaceId: 'workspace-one',
            taskAccessScope: const WorkspaceTaskAccess(),
            taskRepository: const EmptyTaskRepository(),
          ),
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
  fullName: 'Asha Client',
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
