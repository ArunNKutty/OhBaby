import 'dart:convert';

import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/screens/account_screen.dart';
import 'package:baby_feed_tracker/sync/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('explains the missing Google credentials and redirect URI', (tester) async {
    final store = FeedingStore();
    await store.load();
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'configured': false,
            'redirect_uri': 'http://127.0.0.1:47220/v1/auth/google/callback',
            'missing': ['GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET'],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: AccountScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('not set up'), findsOneWidget);
    expect(find.textContaining('GOOGLE_CLIENT_ID'), findsOneWidget);
    expect(find.text('http://127.0.0.1:47220/v1/auth/google/callback'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsNothing);
  });

  testWidgets('shows an error when the API cannot be reached', (tester) async {
    final store = FeedingStore();
    await store.load();
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((request) async => http.Response('nope', 500)),
    );

    await tester.pumpWidget(MaterialApp(home: AccountScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('not reachable').evaluate().isNotEmpty ||
            find.text('Try again').evaluate().isNotEmpty,
        isTrue);
    expect(find.text('Try again'), findsOneWidget);
  });
}
