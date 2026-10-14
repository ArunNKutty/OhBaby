import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/feeding_store.dart';
import '../models/entry.dart';
import 'api_client.dart';
import 'entry_codec.dart';

class SyncService {
  SyncService(this.store);

  final FeedingStore store;
  bool _running = false;

  Future<void> syncNow() async {
    final api = store.api;
    if (api == null || !store.signedIn || _running) return;
    _running = true;
    store.setSyncing(true);
    try {
      await _ensureBaby(api);
      await _push(api);
      await _pull(api);
      await _flushEvents(api);
      store.setSyncResult(at: DateTime.now());
    } on ApiException catch (e) {
      store.track('sync_failed', {'reason': _reason(e)});
      store.setSyncResult(
        error: "Couldn't sync just now. Everything is still saved on this device.",
      );
    } catch (_) {
      store.track('sync_failed', {'reason': 'network'});
      store.setSyncResult(
        error: "Couldn't reach the backup server. Everything is still saved on this device.",
      );
    } finally {
      _running = false;
      store.setSyncing(false);
    }
  }

  Future<void> flushEvents() async {
    final api = store.api;
    if (api == null) return;
    try {
      await _flushEvents(api);
    } catch (_) {
      // The queue stays on the device until the next flush.
    }
  }

  String _reason(ApiException e) {
    if (e.status == 401) return 'unauthorized';
    if (e.status != null) return 'server';
    return 'network';
  }

  Future<String> _token(ApiClient api) async {
    final access = store.accessToken;
    if (access == null || access.isEmpty) {
      throw ApiException('Sign in again to sync.', status: 401);
    }
    return access;
  }

  Future<http.Response> _authed(
    ApiClient api,
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Set<int> ok = const {200},
  }) async {
    Future<http.Response> once(String token) {
      final req = http.Request(method, api.uri(path, query));
      req.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      return api.send(req, ok: ok);
    }

    try {
      return await once(await _token(api));
    } on ApiException catch (e) {
      if (e.status != 401 || store.refreshToken == null) rethrow;
      final session = await api.refresh(store.refreshToken!);
      await store.updateAccessToken(session.accessToken, session.refreshToken);
      return once(session.accessToken);
    }
  }

  Future<void> _ensureBaby(ApiClient api) async {
    // An account that already has a baby keeps using it, so a new device or a
    // fresh sign-in loads that log instead of starting an empty one.
    final res = await _authed(api, 'GET', '/v1/babies');
    final babies = ((jsonDecode(res.body) as Map<String, dynamic>)['babies'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final mine = babies.where((b) => b['id'] == store.babyId).firstOrNull;
    if (mine == null && babies.isNotEmpty) {
      final first = babies.first;
      await store.adoptBaby(first['id'] as String, first['name'] as String? ?? '',
          birthDate: first['birth_date'] as String?);
      return;
    }
    if (mine == null) {
      await _authed(api, 'POST', '/v1/babies', body: {
        'id': store.babyId,
        'name': store.babyName,
        if (store.birthDate != null) 'birth_date': _isoDate(store.birthDate!),
      });
      await store.markBabySynced();
      return;
    }
    if (store.babyDirty) {
      await _authed(api, 'PATCH', '/v1/babies/${store.babyId}', body: {
        'name': store.babyName,
        'birth_date': store.birthDate == null ? null : _isoDate(store.birthDate!),
      });
      await store.markBabySynced();
    } else {
      await store.applyBabyFromServer(
        name: mine['name'] as String? ?? '',
        birthDate: mine['birth_date'] as String?,
      );
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _push(ApiClient api) async {
    final pending = Map<String, String>.of(store.outbox);
    for (final entry in pending.entries) {
      if (entry.value == 'delete') {
        try {
          await _authed(
            api,
            'DELETE',
            '/v1/babies/${store.babyId}/entries/${entry.key}',
            ok: const {200, 404},
          );
        } on ApiException catch (e) {
          if (e.status != 404) rethrow;
        }
      } else {
        final matches = store.entries.where((e) => e.id == entry.key);
        if (matches.isEmpty) {
          await store.ackOutbox(entry.key);
          continue;
        }
        await _authed(
          api,
          'PUT',
          '/v1/babies/${store.babyId}/entries/${entry.key}',
          body: entryToApi(matches.first),
        );
      }
      await store.ackOutbox(entry.key);
    }
  }

  Future<void> _pull(ApiClient api) async {
    final since = store.syncToken ?? '0';
    final res = await _authed(
      api,
      'GET',
      '/v1/babies/${store.babyId}/entries',
      query: {'since': since},
    );
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (json['entries'] as List<dynamic>? ?? const []);
    final remote = <Entry>[];
    final deleted = <String>{};
    for (final row in rows) {
      final map = row as Map<String, dynamic>;
      if (map['deleted_at'] != null) {
        deleted.add(map['id'] as String);
      } else {
        final entry = entryFromApi(map);
        if (entry != null) remote.add(entry);
      }
    }
    await store.applyRemote(remote, deletedIds: deleted);
    final token = json['sync_token'];
    if (token != null) await store.setSyncToken(token.toString());
  }

  Future<void> _flushEvents(ApiClient api) async {
    final batch = store.takeEvents(50);
    if (batch.isEmpty) return;
    final body = {
      'events': [
        for (final event in batch)
          {
            'event_id': event['event_id'],
            'name': event['name'],
            'client_ts': event['client_ts'],
            'anon_id': store.anonId,
            'session_id': store.sessionId,
            'platform': 'web',
            'app_version': '0.1.0',
            'props': event['props'] ?? const {},
          },
      ],
    };
    final req = http.Request('POST', api.uri('/v1/events'));
    req.headers['Content-Type'] = 'application/json';
    if (store.accessToken != null) {
      req.headers['Authorization'] = 'Bearer ${store.accessToken}';
    }
    req.body = jsonEncode(body);
    await api.send(req);
    await store.ackEvents([for (final event in batch) event['event_id'] as String]);
  }
}
