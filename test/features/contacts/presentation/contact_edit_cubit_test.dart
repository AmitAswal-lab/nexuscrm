import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/contact_edit/contact_edit_cubit.dart';

final class _MockContactRepository extends Mock implements ContactRepository {}

final class _MockAssigneeRepository extends Mock
    implements SalesAssigneeRepository {}

void main() {
  late ContactRepository contacts;
  late SalesAssigneeRepository assignees;

  setUpAll(() {
    registerFallbackValue(_leadInput);
    registerFallbackValue(_clientInput);
  });

  setUp(() {
    contacts = _MockContactRepository();
    assignees = _MockAssigneeRepository();
    when(
      () => contacts.updateLead(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => contacts.updateClient(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async {});
  });

  test('admin waits for contact and assignee data', () async {
    final contactStream = StreamController<CrmContact?>.broadcast();
    final assigneeStream = StreamController<List<SalesAssignee>>.broadcast();
    addTearDown(contactStream.close);
    addTearDown(assigneeStream.close);
    _stubContact(contacts, contactStream.stream);
    when(
      () => assignees.watchActiveSalesAssignees(workspaceId: 'workspace-one'),
    ).thenAnswer((_) => assigneeStream.stream);
    final cubit = _adminCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _flush();

    contactStream.add(_lead);
    await _flush();
    expect(cubit.state.status, ContactEditStatus.loading);

    assigneeStream.add(const [_assignee]);
    await _flush();
    expect(cubit.state.status, ContactEditStatus.ready);
    expect(cubit.state.assignees, const [_assignee]);
  });

  test('sales lead updates preserve sales ownership and stage', () async {
    _stubContact(contacts, Stream.value(_lead));
    final cubit = _salesCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _flush();

    await cubit.submit(
      fullName: 'Updated Lead',
      companyName: null,
      email: 'updated@example.com',
      phone: null,
      notes: null,
      ownerId: 'another-user',
      leadStage: LeadStage.proposal,
    );

    final input =
        verify(
              () => contacts.updateLead(
                workspaceId: 'workspace-one',
                contactId: 'contact-one',
                actorUserId: 'sales-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as LeadInput;
    expect(input.ownerId, 'sales-user');
    expect(input.stage, LeadStage.proposal);
    expect(cubit.state.submissionStatus, ContactEditSubmissionStatus.success);
  });

  test('admin client updates can remove the owner', () async {
    _stubContact(contacts, Stream.value(_client));
    when(
      () => assignees.watchActiveSalesAssignees(workspaceId: 'workspace-one'),
    ).thenAnswer((_) => Stream.value(const [_assignee]));
    final cubit = _adminCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _flush();

    await cubit.submit(
      fullName: 'Updated Client',
      companyName: null,
      email: null,
      phone: '+91 90000 00000',
      notes: null,
      ownerId: null,
      leadStage: null,
    );

    final input =
        verify(
              () => contacts.updateClient(
                workspaceId: 'workspace-one',
                contactId: 'contact-one',
                actorUserId: 'admin-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as ClientInput;
    expect(input.ownerId, isNull);
  });

  test('handles missing contacts and typed load failures', () async {
    _stubContact(contacts, Stream.value(null));
    var cubit = _salesCubit(contacts, assignees);
    await _flush();
    expect(cubit.state.status, ContactEditStatus.notFound);
    await cubit.close();

    reset(contacts);
    _stubContact(
      contacts,
      Stream.error(const ContactFailure(ContactFailureCode.networkUnavailable)),
    );
    cubit = _salesCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _flush();
    expect(
      cubit.state.failure,
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );
  });

  test('preserves typed update failures', () async {
    _stubContact(contacts, Stream.value(_lead));
    when(
      () => contacts.updateLead(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenThrow(const ContactFailure(ContactFailureCode.conflict));
    final cubit = _salesCubit(contacts, assignees);
    addTearDown(cubit.close);
    await _flush();

    await cubit.submit(
      fullName: 'Asha Lead',
      companyName: null,
      email: 'asha@example.com',
      phone: null,
      notes: null,
      ownerId: null,
      leadStage: LeadStage.qualified,
    );
    expect(
      cubit.state.submissionFailure,
      const ContactFailure(ContactFailureCode.conflict),
    );
  });
}

void _stubContact(ContactRepository repository, Stream<CrmContact?> stream) {
  when(
    () => repository.watchContact(
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
    ),
  ).thenAnswer((_) => stream);
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _assignee = SalesAssignee(
  userId: 'sales-user',
  workspaceId: 'workspace-one',
  displayName: 'Amit Sales',
  email: 'sales@example.com',
);
const _leadInput = LeadInput(
  fullName: 'Fallback',
  companyName: null,
  email: 'fallback@example.com',
  phone: null,
  notes: null,
  ownerId: null,
  stage: LeadStage.newLead,
);
const _clientInput = ClientInput(
  fullName: 'Fallback',
  companyName: null,
  email: 'fallback@example.com',
  phone: null,
  notes: null,
  ownerId: null,
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
