import 'dart:convert';

import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/main.dart';
import 'package:baby_feed_tracker/screens/login_screen.dart';
import 'package:baby_feed_tracker/screens/main_shell.dart';
import 'package:baby_feed_tracker/screens/splash_screen.dart';
import 'package:baby_feed_tracker/sync/api_client.dart';
import 'package:baby_feed_tracker/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient firebaseOff() => ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({'configured': false, 'missing': ['FIREBASE_API_KEY'], 'setup': []}),
            200,
          )),
    );

void main() {
  testWidgets('splash stays for 3 seconds, then login when signed out', (tester) async {
    final store = FeedingStore();
    await store.load();
    store.api = firebaseOff();

    await tester.pumpWidget(BabyFeedTrackerApp(store: store));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainShell), findsNothing);
    expect(find.textContaining('not set up'), findsOneWidget);
  });

  testWidgets('splash goes to the log when a session is saved', (tester) async {
    final store = FeedingStore();
    await store.load();
    await store.rememberSession(
      accessToken: 'a',
      refreshToken: 'r',
      userId: 'user-1',
      email: 'parent@example.com',
    );

    await tester.pumpWidget(BabyFeedTrackerApp(store: store));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('splash waits for on-device storage before choosing', (tester) async {
    final store = FeedingStore(storageReady: false);
    await store.load();

    await tester.pumpWidget(BabyFeedTrackerApp(store: store, splashDuration: Duration.zero));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SplashScreen), findsOneWidget);

    store.api = firebaseOff();
    store.storageReady = true;
    store.setSyncResult();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  test('signing in on a new device loads the account’s existing baby', () async {
    final store = FeedingStore();
    await store.load();
    await store.rememberSession(
      accessToken: 'a',
      refreshToken: 'r',
      userId: 'user-1',
      email: 'parent@example.com',
    );
    const existing = '11111111-1111-4111-8111-111111111111';
    final requests = <String>[];
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((req) async {
        requests.add('${req.method} ${req.url.path}');
        if (req.url.path == '/v1/babies' && req.method == 'GET') {
          return http.Response(
            jsonEncode({
              'babies': [
                {'id': existing, 'name': 'Bea', 'role': 'owner'},
              ],
            }),
            200,
          );
        }
        if (req.url.path == '/v1/babies/$existing/feedings') {
          return http.Response(jsonEncode({'feedings': [], 'sync_token': '7'}), 200);
        }
        return http.Response('unexpected', 500);
      }),
    );

    await SyncService(store).syncNow();

    expect(store.syncError, isNull);
    expect(store.babyId, existing);
    expect(store.babyName, 'Bea');
    expect(requests, isNot(contains('POST /v1/babies')));
    expect(requests, contains('GET /v1/babies/$existing/feedings'));
  });
}
