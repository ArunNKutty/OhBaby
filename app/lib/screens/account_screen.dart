import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../platform/browser.dart';
import '../sync/api_client.dart';
import '../theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.store});

  final FeedingStore store;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<GoogleAuthStatus> _status;
  String? _error;

  FeedingStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  Future<GoogleAuthStatus> _load() async {
    final api = store.api;
    if (api == null) {
      throw ApiException('The backup server is not configured in this build.');
    }
    return api.googleStatus();
  }

  void _reload() {
    setState(() {
      _error = null;
      _status = _load();
    });
  }

  Future<void> _signIn(GoogleAuthStatus status) async {
    final api = store.api;
    if (api == null || !status.configured) return;
    store.track('sign_in_started');
    final returnTo = '${Uri.base.origin}/';
    redirectBrowser(api.googleStartUri(returnTo).toString());
  }

  Future<void> _signOut() async {
    await store.performSync?.call();
    await store.signOutLocal();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This removes the account and every feeding stored on the server. Feedings on this device are cleared too.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || store.accessToken == null) return;
    try {
      await store.api?.deleteAccount(store.accessToken!);
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
                if (store.syncing) const LinearProgressIndicator(color: AppColors.indigo),
                if (store.syncError != null) ...[
                  const SizedBox(height: 12),
                  Text(store.syncError!, style: const TextStyle(color: AppColors.indigo)),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.indigo)),
                ],
                const SizedBox(height: 20),
                FutureBuilder<GoogleAuthStatus>(
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
                              Text('Checking Google sign-in…'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return _ErrorPane(
                        message: snap.error is ApiException
                            ? (snap.error! as ApiException).message
                            : 'Google sign-in could not be checked.',
                        onRetry: _reload,
                      );
                    }
                    final status = snap.data!;
                    if (!status.configured) {
                      return _SetupPane(status: status);
                    }
                    if (!store.signedIn) {
                      return FilledButton(
                        onPressed: () => _signIn(status),
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

  final GoogleAuthStatus status;

  @override
  Widget build(BuildContext context) {
    final missing = status.missing.isEmpty
        ? 'GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET'
        : status.missing.join(' and ');
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
            'Google sign-in is not set up on this server yet. You can keep logging feedings on this device.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 12),
          const Text('Create a Google Cloud OAuth client of type Web application and set:',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(missing),
          const SizedBox(height: 8),
          const Text('Authorized redirect URI', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(status.redirectUri.isEmpty
              ? 'http://127.0.0.1:47220/v1/auth/google/callback'
              : status.redirectUri),
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
