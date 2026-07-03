import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nexuscrm/features/authentication/data/repositories/firestore_membership_repository.dart';
import 'package:nexuscrm/features/authentication/domain/entities/workspace_membership.dart';
import 'package:nexuscrm/features/authentication/domain/failures/authentication_failure.dart';

final class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ignore: subtype_of_sealed_class
final class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
final class _MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

void main() {
  late FirebaseFirestore firestore;
  late Query<Map<String, dynamic>> collectionGroup;
  late Query<Map<String, dynamic>> filteredQuery;
  late FirestoreMembershipRepository repository;

  setUp(() {
    firestore = _MockFirebaseFirestore();
    collectionGroup = _MockQuery();
    filteredQuery = _MockQuery();
    repository = FirestoreMembershipRepository(firestore);

    when(
      () => firestore.collectionGroup('members'),
    ).thenReturn(collectionGroup);
    when(
      () => collectionGroup.where('userId', isEqualTo: 'user-one'),
    ).thenReturn(filteredQuery);
  });

  test('rejects blank user IDs before querying Firestore', () async {
    await expectLater(
      repository.watchMemberships(userId: '  '),
      emitsError(
        const AuthenticationFailure(AuthenticationFailureCode.invalidData),
      ),
    );
    verifyNever(() => firestore.collectionGroup(any()));
  });

  test('returns sorted, immutable memberships', () async {
    final snapshot = _MockQuerySnapshot();
    final workspaceTwo = _membershipDocument(workspaceId: 'workspace-two');
    final workspaceOne = _membershipDocument(workspaceId: 'workspace-one');
    when(() => snapshot.docs).thenReturn(
      <QueryDocumentSnapshot<Map<String, dynamic>>>[workspaceTwo, workspaceOne],
    );
    when(
      () => filteredQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(snapshot));

    final memberships = await repository
        .watchMemberships(userId: 'user-one')
        .first;

    expect(memberships.map((membership) => membership.workspaceId), <String>[
      'workspace-one',
      'workspace-two',
    ]);
    expect(
      () => memberships.add(
        const WorkspaceMembership(
          workspaceId: 'workspace-three',
          userId: 'user-one',
          role: WorkspaceRole.admin,
          status: MembershipStatus.active,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('maps malformed documents to invalid data', () async {
    final snapshot = _MockQuerySnapshot();
    final document = _membershipDocument(workspaceId: 'workspace-one');
    when(() => document.data()).thenReturn(<String, dynamic>{
      'workspaceId': 'workspace-one',
      'userId': 'user-one',
      'role': 'owner',
      'status': 'active',
    });
    when(
      () => snapshot.docs,
    ).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[document]);
    when(
      () => filteredQuery.snapshots(),
    ).thenAnswer((_) => Stream.value(snapshot));

    await expectLater(
      repository.watchMemberships(userId: 'user-one'),
      emitsError(
        const AuthenticationFailure(AuthenticationFailureCode.invalidData),
      ),
    );
  });

  for (final testCase in <(String, AuthenticationFailureCode)>[
    ('permission-denied', AuthenticationFailureCode.permissionDenied),
    ('unauthenticated', AuthenticationFailureCode.permissionDenied),
    ('unavailable', AuthenticationFailureCode.networkUnavailable),
    ('deadline-exceeded', AuthenticationFailureCode.networkUnavailable),
    ('unknown-code', AuthenticationFailureCode.unknown),
  ]) {
    test('maps ${testCase.$1} to ${testCase.$2.name}', () async {
      when(() => filteredQuery.snapshots()).thenAnswer(
        (_) => Stream<QuerySnapshot<Map<String, dynamic>>>.error(
          FirebaseException(plugin: 'cloud_firestore', code: testCase.$1),
        ),
      );

      await expectLater(
        repository.watchMemberships(userId: 'user-one'),
        emitsError(AuthenticationFailure(testCase.$2)),
      );
    });
  }
}

_MockQueryDocumentSnapshot _membershipDocument({required String workspaceId}) {
  final document = _MockQueryDocumentSnapshot();
  final documentReference = _MockDocumentReference();
  final membersCollection = _MockCollectionReference();
  final workspaceReference = _MockDocumentReference();
  final workspacesCollection = _MockCollectionReference();

  when(() => document.data()).thenReturn(<String, dynamic>{
    'workspaceId': workspaceId,
    'userId': 'user-one',
    'role': 'admin',
    'status': 'active',
  });
  when(() => document.id).thenReturn('user-one');
  when(() => document.reference).thenReturn(documentReference);
  when(() => documentReference.parent).thenReturn(membersCollection);
  when(() => membersCollection.id).thenReturn('members');
  when(() => membersCollection.parent).thenReturn(workspaceReference);
  when(() => workspaceReference.id).thenReturn(workspaceId);
  when(() => workspaceReference.parent).thenReturn(workspacesCollection);
  when(() => workspacesCollection.id).thenReturn('workspaces');

  return document;
}
