import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../sync/api_client.dart';

Future<String> signInWithGoogleFirebase(FirebaseWebConfig config) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: config.appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        authDomain: config.authDomain,
        storageBucket: config.storageBucket.isEmpty ? null : config.storageBucket,
      ),
    );
  }
  final cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  final token = await cred.user?.getIdToken();
  if (token == null || token.isEmpty) {
    throw ApiException('Google did not return a sign-in token.');
  }
  return token;
}

Future<void> signOutFirebase() async {
  if (Firebase.apps.isEmpty) return;
  await FirebaseAuth.instance.signOut();
}

Future<void> deleteFirebaseAccount() async {
  if (Firebase.apps.isEmpty) return;
  await FirebaseAuth.instance.currentUser?.delete();
}
