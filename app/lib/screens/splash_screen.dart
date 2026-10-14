import 'dart:async';

import 'package:flutter/material.dart';

import '../data/feeding_store.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'main_shell.dart';

/// Shown on every launch for [duration], then the log for a signed-in user or
/// the login page for everyone else. The saved session lives in on-device
/// storage, so this also waits for that to open.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.store,
    this.duration = const Duration(seconds: 3),
  });

  final FeedingStore store;
  final Duration duration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_continue());
  }

  Future<void> _continue() async {
    await Future.wait([Future<void>.delayed(widget.duration), _storageReady()]);
    if (!mounted) return;
    final store = widget.store;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) =>
            store.signedIn ? MainShell(store: store) : LoginScreen(store: store),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _storageReady() {
    final store = widget.store;
    if (store.storageReady) return Future.value();
    final done = Completer<void>();
    void check() {
      if (store.storageReady && !done.isCompleted) {
        store.removeListener(check);
        done.complete();
      }
    }

    store.addListener(check);
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BabyAvatar(size: 132),
            const SizedBox(height: 24),
            Text(
              AppLogo.name,
              style: TextStyle(fontFamily: wordmarkFont, color: c.ink, fontSize: 32, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text('Every feed, day and night.', style: TextStyle(color: c.muted, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
