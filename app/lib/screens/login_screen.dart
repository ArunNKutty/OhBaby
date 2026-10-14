import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/sign_in_flow.dart';
import '../data/feeding_store.dart';
import '../sync/api_client.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import 'main_shell.dart';

/// Sign up or log in. Google sign-in creates the account the first time.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});

  final FeedingStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      throw ApiException('The server is not configured in this build.');
    }
    final status = await api.firebaseStatus();
    if (status.configured) unawaited(_finishRedirect(status));
    return status;
  }

  /// A home-screen app signs in with a full-page redirect, so Google's answer
  /// arrives here when the app loads again.
  Future<void> _finishRedirect(FirebaseAuthStatus status) async {
    setState(() => _signingIn = true);
    try {
      if (await completeRedirectSignIn(store, status)) _openLog();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in did not finish. Please try again.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _openLog() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => MainShell(store: store)),
    );
  }

  void _reload() {
    setState(() {
      _error = null;
      _status = _load();
    });
  }

  Future<void> _signIn(FirebaseAuthStatus status) async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      // False means the page is on its way to Google; it signs in on return.
      if (!await signInWithGoogle(store, status)) return;
      _openLog();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Google sign-in did not finish. Please try again.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BabyAvatar(size: 104)),
                const SizedBox(height: 20),
                Text(
                  'Welcome to ${AppLogo.name}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign up or log in to keep everything you log safe in your account, on any phone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 16, height: 1.4),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: FutureBuilder<FirebaseAuthStatus>(
                    future: _status,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(color: c.primary)),
                        );
                      }
                      if (snap.hasError) {
                        return _Message(
                          text: snap.error is ApiException
                              ? (snap.error! as ApiException).message
                              : 'Sign-in could not be checked.',
                          onRetry: _reload,
                        );
                      }
                      final status = snap.data!;
                      if (!status.configured) {
                        return const _Message(
                          text: 'Sign-in is not set up on this server yet. Please check back soon.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _signingIn ? null : () => _signIn(status),
                            icon: _signingIn
                                ? SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: c.onPrimary),
                                  )
                                : const Icon(Icons.login),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'New here? This creates your account.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.muted),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, textAlign: TextAlign.center, style: const TextStyle(height: 1.4)),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ],
    );
  }
}
