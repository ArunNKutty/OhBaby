import '../sync/api_client.dart';

Future<String?> signInWithGoogleFirebase(FirebaseWebConfig config) async {
  throw ApiException('Sign in with Google runs in the browser.');
}

Future<String?> completeGoogleRedirect(FirebaseWebConfig config) async => null;

Future<void> signOutFirebase() async {}

Future<void> deleteFirebaseAccount() async {}
