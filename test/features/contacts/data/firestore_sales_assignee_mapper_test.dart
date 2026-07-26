import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/contacts/data/mappers/firestore_sales_assignee_mapper.dart';

// ignore: subtype_of_sealed_class
final class _MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

void main() {
  group('FirestoreSalesAssigneeMapper', () {
    test('maps an activated invitation membership without a display name', () {
      final assignee = FirestoreSalesAssigneeMapper.fromDocument(
        _memberDocument(
          data: <String, dynamic>{
            'workspaceId': 'workspace-one',
            'userId': 'user-one',
            'email': 'sales.rep@example.com',
            'role': 'sales_rep',
            'status': 'active',
            'invitationId': 'invite-one',
          },
        ),
      );

      expect(assignee.displayName, 'sales.rep@example.com');
      expect(assignee.email, 'sales.rep@example.com');
    });

    test('prefers a stored display name and trims it', () {
      final assignee = FirestoreSalesAssigneeMapper.fromDocument(
        _memberDocument(
          data: <String, dynamic>{
            'workspaceId': 'workspace-one',
            'userId': 'user-one',
            'email': 'sales.rep@example.com',
            'displayName': '  Priya Sharma  ',
            'role': 'sales_rep',
            'status': 'active',
          },
        ),
      );

      expect(assignee.displayName, 'Priya Sharma');
    });

    test('falls back when a display name is blank', () {
      final assignee = FirestoreSalesAssigneeMapper.fromDocument(
        _memberDocument(
          data: <String, dynamic>{
            'workspaceId': 'workspace-one',
            'userId': 'user-one',
            'email': 'sales.rep@example.com',
            'displayName': '   ',
            'role': 'sales_rep',
            'status': 'active',
          },
        ),
      );

      expect(assignee.displayName, 'sales.rep@example.com');
    });

    test('rejects a membership without an email', () {
      expect(
        () => FirestoreSalesAssigneeMapper.fromDocument(
          _memberDocument(
            data: <String, dynamic>{
              'workspaceId': 'workspace-one',
              'userId': 'user-one',
              'role': 'sales_rep',
              'status': 'active',
            },
          ),
        ),
        throwsFormatException,
      );
    });
  });
}

_MockDocumentSnapshot _memberDocument({required Map<String, dynamic> data}) {
  final document = _MockDocumentSnapshot();
  final documentReference = _MockDocumentReference();
  final membersCollection = _MockCollectionReference();
  final workspaceReference = _MockDocumentReference();
  final workspacesCollection = _MockCollectionReference();

  when(() => document.data()).thenReturn(data);
  when(() => document.id).thenReturn('user-one');
  when(() => document.reference).thenReturn(documentReference);
  when(() => documentReference.parent).thenReturn(membersCollection);
  when(() => membersCollection.id).thenReturn('members');
  when(() => membersCollection.parent).thenReturn(workspaceReference);
  when(() => workspaceReference.id).thenReturn('workspace-one');
  when(() => workspaceReference.parent).thenReturn(workspacesCollection);
  when(() => workspacesCollection.id).thenReturn('workspaces');

  return document;
}
