import 'dart:convert';

import 'package:baby_feed_tracker/data/feeding_store.dart';
import 'package:baby_feed_tracker/screens/account_screen.dart';
import 'package:baby_feed_tracker/sync/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('explains the missing Firebase web config', (tester) async {
    final store = FeedingStore();
    await store.load();
    store.api = ApiClient(
      base: 'http://api.test',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'configured': false,
            'missing': ['FIREBASE_API_KEY', 'FIREBASE_PROJECT_ID'],
            'setup': ['Enable the Google sign-in provider in Firebase Authentication.'],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: AccountScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.textContaining('not set up'), findsOneWidget);
    expect(find.textContaining('FIREBASE_API_KEY'), findsOneWidget);
    expect(find.textContaining('Google sign-in provider'), findsOneWidget);
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
