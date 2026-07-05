import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_detail/contact_detail_cubit.dart';
import 'package:nexuscrm/features/contacts/presentation/pages/contact_detail_page.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

void main() {
  late ContactRepository contactRepository;

  setUp(() {
    contactRepository = _MockContactRepository();
  });

  testWidgets('renders lead details for an admin', (tester) async {
    _stubContact(contactRepository, Stream.value(_lead));

    await _pumpDetail(
      tester,
      repository: contactRepository,
      isSalesView: false,
    );

    expect(find.text('Asha Lead'), findsOneWidget);
    expect(find.text('Lead · Qualified'), findsOneWidget);
    expect(find.text('Northstar'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    expect(find.text('Ready to talk.'), findsOneWidget);
    expect(find.text('Assigned sales representative'), findsOneWidget);
    expect(find.text('1 Jan 2026'), findsOneWidget);
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
}) async {
  final cubit = ContactDetailCubit(
    contactRepository: repository,
    workspaceId: 'workspace-one',
    contactId: 'lead-one',
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: ContactDetailPage(isSalesView: isSalesView, onEdit: () {}),
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
