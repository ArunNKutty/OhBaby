import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/feeding.dart';
import '../sync/api_client.dart';
import 'feeding_repository.dart';
import 'memory_repository.dart';

/// In-memory view of the log. Every change goes through the repository.
class FeedingStore extends ChangeNotifier {
  FeedingStore({FeedingRepository? repository, this.storageReady = true})
      : _repo = repository ?? MemoryFeedingRepository();

  FeedingRepository _repo;
  bool storageReady;
  bool _storageOpening = false;
  final List<Feeding> _feedings = [];
  final Map<String, String> _outbox = {};
  final Map<String, String> _meta = {};
  final List<Map<String, dynamic>> _events = [];

  final String sessionId = const Uuid().v4();
  String _babyName = 'My baby';
  String _babyId = '';
  String? syncError;
  DateTime? lastSyncedAt;
  bool syncing = false;
  bool analyticsEnabled = false;
  ApiClient? api;
  Future<void> Function()? performSync;

  List<Feeding> get feedings => List.unmodifiable(_feedings);
  String get babyName => _babyName;
  String get babyId => _babyId;
  bool get signedIn => (_meta['access_token'] ?? '').isNotEmpty;
  String? get userEmail => _meta['user_email'];
  String? get accessToken => _meta['access_token'];
  String? get refreshToken => _meta['refresh_token'];
  Map<String, String> get outbox => Map.unmodifiable(_outbox);
  String? get syncToken => _meta['sync_token'];

  Feeding? get lastFeeding {
    if (_feedings.isEmpty) return null;
    return _feedings.reduce((a, b) => a.start.isAfter(b.start) ? a : b);
  }

  /// Opens drift/SQLite on web after the UI is already visible (memory-first).
  Future<void> attachPersistentStorage(
    Future<FeedingRepository> Function() open,
  ) async {
    if (_storageOpening || storageReady) return;
    _storageOpening = true;
    notifyListeners();
    try {
      final repo = await open();
      final stagedFeedings = List<Feeding>.from(_feedings);
      final stagedOutbox = Map<String, String>.from(_outbox);
      _repo = repo;
      await load();
      for (final feeding in stagedFeedings) {
        if (_feedings.any((f) => f.id == feeding.id)) continue;
        await upsert(feeding);
      }
      for (final entry in stagedOutbox.entries) {
        if (_outbox.containsKey(entry.key)) continue;
        await _queue(entry.key, entry.value);
      }
    } catch (e) {
      setSyncResult(
        error:
            'Saved feedings could not be read yet. You can still log on this device.',
      );
    } finally {
      storageReady = true;
      _storageOpening = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final snap = await _repo.load();
    _feedings
      ..clear()
      ..addAll(snap.feedings);
    _babyName = snap.babyName;
    _babyId = snap.babyId;
    _meta
      ..clear()
      ..addAll(snap.meta);
    _outbox
      ..clear()
      ..addAll(snap.outbox);
    analyticsEnabled = _meta['analytics_enabled'] == 'true';
    final rawQueue = _meta['analytics_queue'];
    _events.clear();
    if (rawQueue != null && rawQueue.isNotEmpty) {
      final list = jsonDecode(rawQueue) as List<dynamic>;
      _events.addAll(list.cast<Map<String, dynamic>>());
    }
    if ((_meta['anon_id'] ?? '').isEmpty) {
      await _putMeta('anon_id', const Uuid().v4());
    }
    notifyListeners();
  }

  String newId() => const Uuid().v4();
  String get anonId => _meta['anon_id'] ?? '';

  Future<void> upsert(Feeding feeding) async {
    final stamped = feeding.copyWith(
      updatedAt: DateTime.now().toUtc(),
      utcOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
    );
    final i = _feedings.indexWhere((f) => f.id == stamped.id);
    if (i >= 0) {
      _feedings[i] = stamped;
    } else {
      _feedings.add(stamped);
    }
    await _repo.upsertFeeding(stamped);
    await _queue(stamped.id, 'upsert');
    notifyListeners();
    await _afterChange();
  }

  Future<void> delete(String id) async {
    _feedings.removeWhere((f) => f.id == id);
    await _repo.deleteFeeding(id);
    await _queue(id, 'delete');
    notifyListeners();
    await _afterChange();
  }

  Future<void> setBabyName(String name) async {
    _babyName = name.trim().isEmpty ? 'My baby' : name.trim();
    await _putMeta('baby_name', _babyName);
    notifyListeners();
    await _afterChange();
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    analyticsEnabled = enabled;
    await _putMeta('analytics_enabled', enabled ? 'true' : 'false');
    if (!enabled) {
      _events.clear();
      await _putMeta('analytics_queue', '[]');
    }
    notifyListeners();
  }

  void track(String name, [Map<String, Object?> props = const {}]) {
    if (!analyticsEnabled) return;
    _events.add({
      'event_id': const Uuid().v4(),
      'name': name,
      'client_ts': DateTime.now().toUtc().toIso8601String(),
      'props': props,
    });
    if (_events.length > 200) {
      _events.removeRange(0, _events.length - 200);
    }
    _putMeta('analytics_queue', jsonEncode(_events));
  }

  List<Map<String, dynamic>> takeEvents(int limit) {
    if (!analyticsEnabled || _events.isEmpty) return const [];
    final n = _events.length < limit ? _events.length : limit;
    return _events.take(n).toList();
  }

  Future<void> ackEvents(List<String> ids) async {
    _events.removeWhere((e) => ids.contains(e['event_id']));
    await _putMeta('analytics_queue', jsonEncode(_events));
  }

  Future<void> rememberSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String email,
  }) async {
    await _putMeta('access_token', accessToken);
    await _putMeta('refresh_token', refreshToken);
    await _putMeta('user_id', userId);
    await _putMeta('user_email', email);
    notifyListeners();
  }

  Future<void> updateAccessToken(String accessToken, String? refreshToken) async {
    await _putMeta('access_token', accessToken);
    if (refreshToken != null) await _putMeta('refresh_token', refreshToken);
  }

  Future<void> setSyncToken(String token) => _putMeta('sync_token', token);

  Future<void> clearOutbox() async {
    final ids = _outbox.keys.toList();
    _outbox.clear();
    for (final id in ids) {
      await _repo.removeOutbox(id);
    }
  }

  Future<void> ackOutbox(String id) async {
    _outbox.remove(id);
    await _repo.removeOutbox(id);
  }

  Future<void> applyRemote(List<Feeding> remote, {required Set<String> deletedIds}) async {
    for (final id in deletedIds) {
      _feedings.removeWhere((f) => f.id == id);
      await _repo.deleteFeeding(id);
    }
    for (final feeding in remote) {
      if (_outbox[feeding.id] == 'upsert') continue;
      final i = _feedings.indexWhere((f) => f.id == feeding.id);
      if (i >= 0) {
        final local = _feedings[i];
        final localAt = local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteAt = feeding.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (remoteAt.isBefore(localAt)) continue;
        _feedings[i] = feeding;
      } else {
        _feedings.add(feeding);
      }
      await _repo.upsertFeeding(feeding);
    }
    notifyListeners();
  }

  Future<void> signOutLocal() async {
    _feedings.clear();
    _outbox.clear();
    _events.clear();
    final anon = _meta['anon_id'];
    await _repo.wipe();
    _meta.clear();
    _babyName = 'My baby';
    _babyId = const Uuid().v4();
    await _repo.setMeta('baby_id', _babyId);
    await _repo.setMeta('baby_name', _babyName);
    if (anon != null) await _putMeta('anon_id', anon);
    analyticsEnabled = false;
    syncError = null;
    lastSyncedAt = null;
    notifyListeners();
  }

  void setSyncing(bool value) {
    syncing = value;
    notifyListeners();
  }

  void setSyncResult({String? error, DateTime? at}) {
    syncError = error;
    if (at != null) lastSyncedAt = at;
    notifyListeners();
  }

  Future<void> _queue(String id, String op) async {
    _outbox[id] = op;
    await _repo.setOutbox(id, op);
  }

  Future<void> _putMeta(String key, String value) async {
    _meta[key] = value;
    await _repo.setMeta(key, value);
  }

  Future<void> _afterChange() async {
    if (!signedIn) return;
    final sync = performSync;
    if (sync != null) await sync();
  }
}
