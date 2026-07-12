import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';
import 'package:nexuscrm/features/activities/domain/repositories/activity_repository.dart';
import 'package:nexuscrm/features/activities/presentation/cubit/call_note_form/call_note_form_cubit.dart';
import 'package:nexuscrm/features/activities/presentation/pages/call_note_form_page.dart';

final class _MockActivityRepository extends Mock
    implements ActivityRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CallNoteInput(outcome: CallOutcome.connected, note: null),
    );
  });

  test('creates a call note for the selected contact and actor', () async {
    final repository = _MockActivityRepository();
    when(
      () => repository.createCallNote(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) async => 'call-note-one');
    final cubit = CallNoteFormCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
      actorUserId: 'sales-user',
    );
    addTearDown(cubit.close);

    await cubit.submit(
      const CallNoteInput(
        outcome: CallOutcome.voicemail,
        note: 'Call back on Monday.',
      ),
    );

    verify(
      () => repository.createCallNote(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'sales-user',
        input: const CallNoteInput(
          outcome: CallOutcome.voicemail,
          note: 'Call back on Monday.',
        ),
      ),
    ).called(1);
    expect(cubit.state.submissionStatus, CallNoteSubmissionStatus.success);
  });

  testWidgets('requires an outcome before saving a call note', (tester) async {
    final repository = _MockActivityRepository();
    final cubit = CallNoteFormCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
      actorUserId: 'sales-user',
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CallNoteFormPage(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save call note'));
    await tester.pump();

    expect(find.text('Choose a call outcome.'), findsOneWidget);
    verifyNever(
      () => repository.createCallNote(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    );
  });

  testWidgets('submits the selected outcome and optional note', (tester) async {
    final repository = _MockActivityRepository();
    final completion = Completer<String>();
    when(
      () => repository.createCallNote(
        workspaceId: any(named: 'workspaceId'),
        contactId: any(named: 'contactId'),
        actorUserId: any(named: 'actorUserId'),
        input: any(named: 'input'),
      ),
    ).thenAnswer((_) => completion.future);
    final cubit = CallNoteFormCubit(
      activityRepository: repository,
      workspaceId: 'workspace-one',
      contactId: 'contact-one',
      actorUserId: 'sales-user',
    );
    addTearDown(cubit.close);
    addTearDown(() {
      if (!completion.isCompleted) {
        completion.complete('call-note-one');
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CallNoteFormPage(),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<CallOutcome>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No answer').last);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Call notes (optional)'),
      'Try again tomorrow.',
    );
    await tester.tap(find.text('Save call note'));
    await tester.pump();

    verify(
      () => repository.createCallNote(
        workspaceId: 'workspace-one',
        contactId: 'contact-one',
        actorUserId: 'sales-user',
        input: const CallNoteInput(
          outcome: CallOutcome.noAnswer,
          note: 'Try again tomorrow.',
        ),
      ),
    ).called(1);
  });
}
