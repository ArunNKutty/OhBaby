import '../data/feeding_store.dart';
import '../sync/api_client.dart';
import 'firebase_sign_in.dart';

/// Signs in with Google and starts this device's session. The first sign-in
/// creates the account on the server, so this is both sign up and log in.
Future<void> signInWithGoogle(FeedingStore store, FirebaseAuthStatus status) async {
  final api = store.api;
  final web = status.web;
  if (api == null || !status.configured || web == null) {
    throw ApiException('Sign-in is not set up on this server yet.');
  }
  store.track('sign_in_started');
  final idToken = await signInWithGoogleFirebase(web);
  final session = await api.exchangeFirebase(idToken);
  await store.rememberSession(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    userId: session.userId,
    email: session.email,
  );
  store.track('sign_in_completed');
  await store.performSync?.call();
}
