import '../data/feeding_store.dart';
import '../sync/api_client.dart';
import 'firebase_sign_in.dart';

/// Signs in with Google and starts this device's session. The first sign-in
/// creates the account on the server, so this is both sign up and log in.
/// Returns false when the page is leaving for Google's sign-in page instead;
/// [completeRedirectSignIn] finishes that when the app loads again.
Future<bool> signInWithGoogle(FeedingStore store, FirebaseAuthStatus status) async {
  final web = _web(store, status);
  store.track('sign_in_started');
  final idToken = await signInWithGoogleFirebase(web);
  if (idToken == null) return false;
  await _startSession(store, idToken);
  return true;
}

/// Finishes a redirect sign-in that just came back. Returns false if there was none.
Future<bool> completeRedirectSignIn(FeedingStore store, FirebaseAuthStatus status) async {
  final idToken = await completeGoogleRedirect(_web(store, status));
  if (idToken == null) return false;
  await _startSession(store, idToken);
  return true;
}

FirebaseWebConfig _web(FeedingStore store, FirebaseAuthStatus status) {
  final web = status.web;
  if (store.api == null || !status.configured || web == null) {
    throw ApiException('Sign-in is not set up on this server yet.');
  }
  return web;
}

Future<void> _startSession(FeedingStore store, String idToken) async {
  final session = await store.api!.exchangeFirebase(idToken);
  await store.rememberSession(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    userId: session.userId,
    email: session.email,
  );
  store.track('sign_in_completed');
  await store.performSync?.call();
}
