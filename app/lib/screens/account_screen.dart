import 'package:flutter/material.dart';

import '../auth/firebase_sign_in.dart';
import '../data/feeding_store.dart';
import '../sync/api_client.dart';
import '../theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.store});

  final FeedingStore store;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<FirebaseAuthStatus> _status;
  String? _error;
  bool _signingIn = false;

  FeedingStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  Future<FirebaseAuthStatus> _load() async {
    final api = store.api;
    if (api == null) {
      throw ApiException('The backup server is not configured in this build.');
    }
    return api.firebaseStatus();
  }

  void _reload() {
    setState(() {
      _error = null;
      _status = _load();
    });
  }

  Future<void> _signIn(FirebaseAuthStatus status) async {
    final api = store.api;
    final web = status.web;
    if (api == null || !status.configured || web == null || _signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    store.track('sign_in_started');
    try {
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
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Google sign-in did not finish. You can keep logging on this device.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await store.performSync?.call();
    try {
      await signOutFirebase();
    } catch (_) {}
    await store.signOutLocal();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes the account and every feeding stored on the server, and signs you out of Google on this device. Feedings on this device are cleared too.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || store.accessToken == null) return;
    try {
      try {
        await deleteFirebaseAccount();
      } catch (_) {
        setState(() => _error = 'The Google account stayed signed in here. The feeding backup was still removed.');
      }
      await store.api?.deleteAccount(store.accessToken!);
      await signOutFirebase();
      await store.signOutLocal();
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        title: const Text('Account'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  store.signedIn ? 'Signed in' : 'On this device',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  store.signedIn
                      ? 'Feedings for ${store.babyName} back up with ${store.userEmail}.'
                      : 'Feedings stay on this device until you sign in with Google.',
                  style: const TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (store.syncing || _signingIn) const LinearProgressIndicator(color: AppColors.indigo),
                if (store.syncError != null) ...[
                  const SizedBox(height: 12),
                  Text(store.syncError!, style: const TextStyle(color: AppColors.indigo)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.indigo)),
                ],
                const SizedBox(height: 20),
                FutureBuilder<FirebaseAuthStatus>(
                  future: _status,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.indigo),
                              SizedBox(height: 12),
                              Text('Checking sign-in…'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return _ErrorPane(
                        message: snap.error is ApiException
                            ? (snap.error! as ApiException).message
                            : 'Sign-in could not be checked.',
                        onRetry: _reload,
                      );
                    }
                    final status = snap.data!;
                    if (!status.configured) {
                      return _SetupPane(status: status);
                    }
                    if (!store.signedIn) {
                      return FilledButton(
                        onPressed: _signingIn ? null : () => _signIn(status),
                        child: const Text('Sign in with Google'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: store.syncing ? null : () => store.performSync?.call(),
                          child: const Text('Sync now'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(onPressed: _signOut, child: const Text('Sign out')),
                        TextButton(onPressed: _delete, child: const Text('Delete account')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.indigo,
                  title: const Text('Share anonymous usage'),
                  subtitle: const Text(
                    'Counts things like “a bottle was saved”, never the name, notes, or exact times. Off until you turn it on.',
                  ),
                  value: store.analyticsEnabled,
                  onChanged: (v) => store.setAnalyticsEnabled(v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupPane extends StatelessWidget {
  const _SetupPane({required this.status});

  final FirebaseAuthStatus status;

  @override
  Widget build(BuildContext context) {
    final missing = status.missing.isEmpty
        ? 'the Firebase web app settings'
        : status.missing.join('\n');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sign in with Google is not set up on this server yet. You can keep logging feedings on this device.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text('Set these environment variables from the Firebase web app config:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(missing),
          if (status.setup.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final line in status.setup) ...[
              Text(line, style: const TextStyle(height: 1.4)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 8),
        const Text(
          'Feedings on this device are safe. Sign-in needs the API.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
