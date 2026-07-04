import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:nexuscrm/app/app.dart';
import 'package:nexuscrm/features/authentication/data/repositories/firebase_authentication_repository.dart';
import 'package:nexuscrm/features/authentication/data/repositories/firestore_membership_repository.dart';
import 'package:nexuscrm/features/contacts/data/repositories/firestore_contact_repository.dart';
import 'package:nexuscrm/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    NexusCrmApp(
      authenticationRepository: FirebaseAuthenticationRepository(
        FirebaseAuth.instance,
      ),
      membershipRepository: FirestoreMembershipRepository(
        FirebaseFirestore.instance,
      ),
      contactRepository: FirestoreContactRepository(FirebaseFirestore.instance),
    ),
  );
}
