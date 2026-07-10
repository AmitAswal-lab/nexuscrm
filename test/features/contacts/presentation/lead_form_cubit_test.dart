import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/domain/entities/contact_input.dart';
import 'package:nexuscrm/features/contacts/domain/entities/crm_contact.dart';
import 'package:nexuscrm/features/contacts/domain/entities/sales_assignee.dart';
import 'package:nexuscrm/features/contacts/domain/failures/contact_failure.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexuscrm/features/contacts/domain/repositories/sales_assignee_repository.dart';
import 'package:nexuscrm/features/contacts/presentation/cubit/lead_form/lead_form_cubit.dart';

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
    when(
      () => contactRepository.createLead(
        workspaceId: any(named: 'workspaceId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async => 'lead-one');
  });

  test('sales-created leads are always assigned to the sales user', () async {
    final cubit = _salesCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);

    await cubit.submit(
      fullName: 'Asha Lead',
      companyName: null,
      email: 'asha@example.com',
      phone: null,
      notes: null,
      ownerId: 'another-user',
      stage: LeadStage.qualified,
    );

    final input =
        verify(
              () => contactRepository.createLead(
                workspaceId: 'workspace-one',
                actorUserId: 'sales-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as LeadInput;

    expect(input.ownerId, 'sales-user');
    expect(input.stage, LeadStage.qualified);
    expect(cubit.state.submissionStatus, LeadFormSubmissionStatus.success);
    verifyNever(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: any(named: 'workspaceId'),
      ),
    );
  });

  test('admin directory loads active assignees for selection', () async {
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer((_) => Stream.value(const <SalesAssignee>[_assignee]));

    final cubit = _adminCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    expect(cubit.state.assigneeStatus, AssigneeDirectoryStatus.ready);
    expect(cubit.state.assignees, const <SalesAssignee>[_assignee]);

    await cubit.submit(
      fullName: 'Assigned Lead',
      companyName: null,
      email: null,
      phone: '+91 90000 00000',
      notes: null,
      ownerId: 'sales-user',
      stage: LeadStage.newLead,
    );

    final input =
        verify(
              () => contactRepository.createLead(
                workspaceId: 'workspace-one',
                actorUserId: 'admin-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as LeadInput;
    expect(input.ownerId, 'sales-user');
  });

  test('admin can create an unassigned lead', () async {
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer((_) => Stream.value(const <SalesAssignee>[]));

    final cubit = _adminCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    await cubit.submit(
      fullName: 'Unassigned Lead',
      companyName: null,
      email: 'lead@example.com',
      phone: null,
      notes: null,
      ownerId: null,
      stage: LeadStage.newLead,
    );

    final input =
        verify(
              () => contactRepository.createLead(
                workspaceId: 'workspace-one',
                actorUserId: 'admin-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as LeadInput;
    expect(input.ownerId, isNull);
  });

  test('preserves directory failures and retries the subscription', () async {
    final controller = StreamController<List<SalesAssignee>>.broadcast();
    addTearDown(controller.close);
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer((_) => controller.stream);

    final cubit = _adminCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    controller.addError(
      const ContactFailure(ContactFailureCode.permissionDenied),
    );
    await _flushAsync();

    expect(cubit.state.assigneeStatus, AssigneeDirectoryStatus.failure);
    expect(
      cubit.state.assigneeFailure,
      const ContactFailure(ContactFailureCode.permissionDenied),
    );

    await cubit.loadAssignees();

    verify(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).called(2);
  });

  test('admin can create an unassigned lead after directory failure', () async {
    when(
      () => salesAssigneeRepository.watchActiveSalesAssignees(
        workspaceId: 'workspace-one',
      ),
    ).thenAnswer(
      (_) => Stream.error(const ContactFailure(ContactFailureCode.invalidData)),
    );

    final cubit = _adminCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);
    await _flushAsync();

    await cubit.submit(
      fullName: 'Unassigned Lead',
      companyName: null,
      email: 'lead@example.com',
      phone: null,
      notes: null,
      ownerId: 'stale-sales-user',
      stage: LeadStage.newLead,
    );

    final input =
        verify(
              () => contactRepository.createLead(
                workspaceId: 'workspace-one',
                actorUserId: 'admin-user',
                input: captureAny(named: 'input'),
              ),
            ).captured.single
            as LeadInput;
    expect(input.ownerId, isNull);
    expect(cubit.state.submissionStatus, LeadFormSubmissionStatus.success);
  });

  test('reports when a lead save is still waiting for Firestore', () async {
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

    final submission = cubit.submit(
      fullName: 'Asha Lead',
      companyName: null,
      email: 'asha@example.com',
      phone: null,
      notes: null,
      ownerId: null,
      stage: LeadStage.newLead,
    );
    await _flushAsync();

    expect(
      cubit.state.submissionStatus,
      LeadFormSubmissionStatus.waitingForSync,
    );

    completion.complete('lead-one');
    await submission;
    expect(cubit.state.submissionStatus, LeadFormSubmissionStatus.success);
  });

  test('preserves typed lead submission failures', () async {
    when(
      () => contactRepository.createLead(
        workspaceId: any(named: 'workspaceId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenThrow(const ContactFailure(ContactFailureCode.networkUnavailable));
    final cubit = _salesCubit(contactRepository, salesAssigneeRepository);
    addTearDown(cubit.close);

    await cubit.submit(
      fullName: 'Asha Lead',
      companyName: null,
      email: 'asha@example.com',
      phone: null,
      notes: null,
      ownerId: null,
      stage: LeadStage.newLead,
    );

    expect(cubit.state.submissionStatus, LeadFormSubmissionStatus.failure);
    expect(
      cubit.state.submissionFailure,
      const ContactFailure(ContactFailureCode.networkUnavailable),
    );
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

LeadFormCubit _adminCubit(
  ContactRepository contactRepository,
  SalesAssigneeRepository salesAssigneeRepository,
) {
  return LeadFormCubit(
    contactRepository: contactRepository,
    salesAssigneeRepository: salesAssigneeRepository,
    workspaceId: 'workspace-one',
    actorUserId: 'admin-user',
    requiresAssigneeDirectory: true,
  );
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _assignee = SalesAssignee(
  userId: 'sales-user',
  workspaceId: 'workspace-one',
  displayName: 'Amit Sales',
  email: 'sales@example.com',
);
