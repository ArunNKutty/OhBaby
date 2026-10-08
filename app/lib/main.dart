import 'dart:async';

import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/drift_repository.dart';
import 'data/feeding_store.dart';
import 'platform/browser.dart';
import 'screens/main_shell.dart';
import 'sync/api_client.dart';
import 'sync/sync_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Future<FeedingStore> _ready;

  @override
  void initState() {
    super.initState();
    _ready = openStore();
  }

  Future<FeedingStore> openStore() async {
    final db = AppDatabase();
    final store = FeedingStore(repository: DriftFeedingRepository(db));
    await store.load();
    final api = ApiClient();
    final sync = SyncService(store);
    store.api = api;
    store.performSync = sync.syncNow;
    return store;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FeedingStore>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _BootShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Opening your feeding log…', style: TextStyle(color: Colors.white)),
              ],
            ),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return _BootShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'The feeding log could not be opened on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _ready = openStore()),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        return BabyFeedTrackerApp(store: snap.data!, backgroundTasks: true);
      },
    );
  }
}

class _BootShell extends StatelessWidget {
  const _BootShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: AppColors.indigo,
        body: Center(
          child: Padding(padding: const EdgeInsets.all(32), child: child),
        ),
      ),
    );
  }
}

class BabyFeedTrackerApp extends StatefulWidget {
  const BabyFeedTrackerApp({super.key, required this.store, this.backgroundTasks = false});

  final FeedingStore store;
  final bool backgroundTasks;

  @override
  State<BabyFeedTrackerApp> createState() => _BabyFeedTrackerAppState();
}

class _BabyFeedTrackerAppState extends State<BabyFeedTrackerApp> with WidgetsBindingObserver {
  Timer? _syncTimer;
  Timer? _eventTimer;

  @override
  void initState() {
    super.initState();
    if (!widget.backgroundTasks) return;
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      widget.store.performSync?.call();
    });
    _eventTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final api = widget.store.api;
      if (api == null) return;
      SyncService(widget.store).flushEvents();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  Future<void> _onOpen() async {
    final params = Uri.base.queryParameters;
    final code = params['auth_code'];
    final error = params['auth_error'];
    if (code != null && code.isNotEmpty && widget.store.api != null) {
      try {
        final session = await widget.store.api!.exchangeCode(code);
        await widget.store.rememberSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userId: session.userId,
          email: session.email,
        );
        widget.store.track('sign_in_completed');
      } on ApiException {
        widget.store.setSyncResult(
          error: 'Google sign-in did not finish. You can keep logging on this device.',
        );
      }
      replaceBrowserUrl('${Uri.base.origin}/');
    } else if (error != null) {
      widget.store.setSyncResult(
        error: 'Google sign-in did not finish. You can keep logging on this device.',
      );
      replaceBrowserUrl('${Uri.base.origin}/');
    }
    widget.store.track('app_opened', {'display_mode': displayMode()});
    await widget.store.performSync?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      final api = widget.store.api;
      if (api != null) SyncService(widget.store).flushEvents();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _eventTimer?.cancel();
    if (widget.backgroundTasks) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oh baby baby!',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: MainShell(store: widget.store),
    );
  }
}
