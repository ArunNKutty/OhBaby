import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../platform/browser.dart';
import '../sync/api_client.dart';

Future<void> _init(FirebaseWebConfig config) async {
  if (Firebase.apps.isNotEmpty) return;
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

/// Returns the Firebase ID token, or null when the page is leaving for Google.
/// An app opened from the iPhone home screen cannot get a popup's answer back,
/// so it signs in with a full-page redirect and [completeGoogleRedirect] picks
/// up the result when the app loads again.
Future<String?> signInWithGoogleFirebase(FirebaseWebConfig config) async {
  await _init(config);
  if (displayMode() == 'standalone') {
    await FirebaseAuth.instance.signInWithRedirect(GoogleAuthProvider());
    return null;
  }
  final cred = await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  return _token(cred);
}

/// The ID token from a redirect sign-in that just came back, or null if none.
Future<String?> completeGoogleRedirect(FirebaseWebConfig config) async {
  await _init(config);
  final cred = await FirebaseAuth.instance.getRedirectResult();
  if (cred.user == null) return null;
  return _token(cred);
}

Future<String> _token(UserCredential cred) async {
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
