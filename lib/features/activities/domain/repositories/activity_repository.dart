import 'package:nexuscrm/features/activities/domain/entities/call_note.dart';
import 'package:nexuscrm/features/activities/domain/entities/call_note_input.dart';

abstract interface class ActivityRepository {
  Stream<List<CallNote>> watchCallNotes({
    required String workspaceId,
    required String contactId,
  });

  Future<String> createCallNote({
    required String workspaceId,
    required String contactId,
    required String actorUserId,
    required CallNoteInput input,
  });
}
