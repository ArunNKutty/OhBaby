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
  final store = FeedingStore(storageReady: false);
  final api = ApiClient();
  final sync = SyncService(store);
  store
    ..api = api
    ..performSync = sync.syncNow;

  unawaited(
    store.attachPersistentStorage(() async {
      final db = AppDatabase();
      return DriftFeedingRepository(db);
    }),
  );

  runApp(BabyFeedTrackerApp(store: store, backgroundTasks: true));
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      hideBootSplash();
      _onOpen();
    });
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
