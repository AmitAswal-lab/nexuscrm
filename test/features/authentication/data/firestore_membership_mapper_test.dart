import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/authentication/data/mappers/firestore_membership_mapper.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';

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
  group('FirestoreMembershipMapper', () {
    for (final testCase in <(String, String, WorkspaceRole, MembershipStatus)>[
      ('admin', 'invited', WorkspaceRole.admin, MembershipStatus.invited),
      ('admin', 'active', WorkspaceRole.admin, MembershipStatus.active),
      (
        'sales_rep',
        'suspended',
        WorkspaceRole.salesRep,
        MembershipStatus.suspended,
      ),
      (
        'sales_rep',
        'revoked',
        WorkspaceRole.salesRep,
        MembershipStatus.revoked,
      ),
    ]) {
      test('maps ${testCase.$1}/${testCase.$2}', () {
        final document = _membershipDocument(
          role: testCase.$1,
          status: testCase.$2,
        );

        expect(
          FirestoreMembershipMapper.fromDocument(document),
          WorkspaceMembership(
            workspaceId: 'workspace-one',
            userId: 'user-one',
            role: testCase.$3,
            status: testCase.$4,
          ),
        );
      });
    }

    test('rejects missing required fields', () {
      final document = _membershipDocument(
        role: 'admin',
        status: 'active',
        dataOverride: <String, dynamic>{
          'workspaceId': 'workspace-one',
          'role': 'admin',
          'status': 'active',
        },
      );

      expect(
        () => FirestoreMembershipMapper.fromDocument(document),
        throwsFormatException,
      );
    });

    test('rejects document and data ID mismatches', () {
      final document = _membershipDocument(
        role: 'admin',
        status: 'active',
        dataOverride: <String, dynamic>{
          'workspaceId': 'other-workspace',
          'userId': 'user-one',
          'role': 'admin',
          'status': 'active',
        },
      );

      expect(
        () => FirestoreMembershipMapper.fromDocument(document),
        throwsFormatException,
      );
    });

    test('rejects unsupported roles and statuses', () {
      expect(
        () => FirestoreMembershipMapper.fromDocument(
          _membershipDocument(role: 'owner', status: 'active'),
        ),
        throwsFormatException,
      );
      expect(
        () => FirestoreMembershipMapper.fromDocument(
          _membershipDocument(role: 'admin', status: 'disabled'),
        ),
        throwsFormatException,
      );
    });

    test('rejects documents outside the membership path', () {
      final document = _membershipDocument(role: 'admin', status: 'active');
      final membersCollection = document.reference.parent;
      when(() => membersCollection.id).thenReturn('not-members');

      expect(
        () => FirestoreMembershipMapper.fromDocument(document),
        throwsFormatException,
      );
    });
  });
}

_MockDocumentSnapshot _membershipDocument({
  required String role,
  required String status,
  Map<String, dynamic>? dataOverride,
}) {
  final document = _MockDocumentSnapshot();
  final documentReference = _MockDocumentReference();
  final membersCollection = _MockCollectionReference();
  final workspaceReference = _MockDocumentReference();
  final workspacesCollection = _MockCollectionReference();

  when(() => document.data()).thenReturn(
    dataOverride ??
        <String, dynamic>{
          'workspaceId': 'workspace-one',
          'userId': 'user-one',
          'role': role,
          'status': status,
        },
  );
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
