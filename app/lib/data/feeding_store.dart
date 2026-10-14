import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/entry.dart';
import '../models/live_timer.dart';
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
  final List<Entry> _entries = [];
  final Map<String, String> _outbox = {};
  final Map<String, String> _meta = {};
  final List<Map<String, dynamic>> _events = [];

  final String sessionId = const Uuid().v4();
  String _babyName = 'My baby';
  String _babyId = '';
  Uint8List? _babyPhoto;
  String? syncError;
  DateTime? lastSyncedAt;
  bool syncing = false;
  bool analyticsEnabled = false;
  ApiClient? api;
  Future<void> Function()? performSync;

  /// The clock, replaceable in tests.
  DateTime Function() now = DateTime.now;

  List<Entry> get entries => List.unmodifiable(_entries);
  String get babyName => _babyName;
  String get babyId => _babyId;
  Uint8List? get babyPhoto => _babyPhoto;
  bool get signedIn => (_meta['access_token'] ?? '').isNotEmpty;
  String? get userEmail => _meta['user_email'];
  String? get accessToken => _meta['access_token'];
  String? get refreshToken => _meta['refresh_token'];
  Map<String, String> get outbox => Map.unmodifiable(_outbox);
  String? get syncToken => _meta['sync_token'];

  DateTime? get birthDate {
    final raw = _meta['baby_birth_date'];
    return raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
  }

  /// The name or birth date changed here and the server has not heard yet.
  bool get babyDirty => _meta['baby_dirty'] == '1';

  ThemeMode get themeMode => switch (_meta['appearance']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  LiveTimer? get liveTimer {
    final raw = _meta['live_timer'];
    if (raw == null || raw.isEmpty) return null;
    try {
      return LiveTimer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Entry? _latest(bool Function(Entry e) test) {
    Entry? best;
    for (final e in _entries) {
      if (test(e) && (best == null || e.start.isAfter(best.start))) best = e;
    }
    return best;
  }

  Entry? get lastFeeding => _latest((e) => e.isFeed);

  /// The side the last breastfeed ended on.
  BreastSide? get lastEndSide => _latest((e) => e.type == EntryType.breast && e.endSide != null)?.endSide;

  /// The side to offer next: the other one from where the last feed ended.
  BreastSide get nextSide => lastEndSide == BreastSide.left ? BreastSide.right : BreastSide.left;

  /// The last bottle with an amount, for "Use last amount" and quick add.
  Entry? get lastBottle => _latest((e) => e.isBottle && e.amountMl > 0);

  /// Opens drift/SQLite on web after the UI is already visible (memory-first).
  Future<void> attachPersistentStorage(Future<FeedingRepository> Function() open) async {
    if (_storageOpening || storageReady) return;
    _storageOpening = true;
    notifyListeners();
    try {
      final repo = await open();
      final stagedEntries = List<Entry>.from(_entries);
      final stagedOutbox = Map<String, String>.from(_outbox);
      _repo = repo;
      await load();
      for (final entry in stagedEntries) {
        if (_entries.any((e) => e.id == entry.id)) continue;
        await upsert(entry);
      }
      for (final queued in stagedOutbox.entries) {
        if (_outbox.containsKey(queued.key)) continue;
        await _queue(queued.key, queued.value);
      }
    } catch (e) {
      setSyncResult(error: 'Saved entries could not be read yet. You can still log on this device.');
    } finally {
      storageReady = true;
      _storageOpening = false;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final snap = await _repo.load();
    _entries
      ..clear()
      ..addAll(snap.entries);
    _babyName = snap.babyName;
    _babyId = snap.babyId;
    _babyPhoto = snap.babyPhoto;
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

  Future<void> upsert(Entry entry) async {
    final at = now();
    final stamped = entry.copyWith(updatedAt: at.toUtc(), utcOffsetMin: at.timeZoneOffset.inMinutes);
    final i = _entries.indexWhere((e) => e.id == stamped.id);
    if (i >= 0) {
      _entries[i] = stamped;
    } else {
      _entries.add(stamped);
    }
    await _repo.upsertEntry(stamped);
    await _queue(stamped.id, 'upsert');
    notifyListeners();
    await _afterChange();
  }

  Future<void> delete(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _repo.deleteEntry(id);
    await _queue(id, 'delete');
    notifyListeners();
    await _afterChange();
  }

  Future<void> setBabyName(String name) async {
    _babyName = name.trim().isEmpty ? 'My baby' : name.trim();
    await _putMeta('baby_name', _babyName);
    await _putMeta('baby_dirty', '1');
    notifyListeners();
    await _afterChange();
  }

  Future<void> setBirthDate(DateTime? date) async {
    await _putMeta('baby_birth_date', date == null ? '' : _isoDate(date));
    await _putMeta('baby_dirty', '1');
    notifyListeners();
    await _afterChange();
  }

  /// The server has the name and birth date now.
  Future<void> markBabySynced() => _putMeta('baby_dirty', '0');

  /// Takes the name and birth date the server has for this baby.
  Future<void> applyBabyFromServer({required String name, String? birthDate}) async {
    if (name.trim().isNotEmpty) {
      _babyName = name.trim();
      await _putMeta('baby_name', _babyName);
    }
    await _putMeta('baby_birth_date', birthDate ?? '');
    notifyListeners();
  }

  /// Device-only: the photo is never sent to the server.
  Future<void> setBabyPhoto(Uint8List? bytes) async {
    _babyPhoto = bytes;
    await _repo.setBlob('baby_photo', bytes);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _putMeta('appearance', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    notifyListeners();
  }

  Future<void> setLiveTimer(LiveTimer? timer) async {
    if (timer == null) {
      _meta.remove('live_timer');
      await _repo.removeMeta('live_timer');
    } else {
      await _putMeta('live_timer', jsonEncode(timer.toJson()));
    }
    notifyListeners();
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
      'client_ts': now().toUtc().toIso8601String(),
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

  /// Switches to a baby the account already has on the server, so signing in on
  /// another device shows the same log. Entries not yet sent follow the baby,
  /// and the next pull starts from the beginning.
  Future<void> adoptBaby(String id, String name, {String? birthDate}) async {
    _babyId = id;
    if (name.trim().isNotEmpty) _babyName = name.trim();
    await _putMeta('baby_id', _babyId);
    await _putMeta('baby_name', _babyName);
    await _putMeta('baby_birth_date', birthDate ?? '');
    await _putMeta('baby_dirty', '0');
    await _putMeta('sync_token', '0');
    notifyListeners();
  }

  Future<void> ackOutbox(String id) async {
    _outbox.remove(id);
    await _repo.removeOutbox(id);
  }

  Future<void> applyRemote(List<Entry> remote, {required Set<String> deletedIds}) async {
    for (final id in deletedIds) {
      _entries.removeWhere((e) => e.id == id);
      await _repo.deleteEntry(id);
    }
    for (final entry in remote) {
      if (_outbox[entry.id] == 'upsert') continue;
      final i = _entries.indexWhere((e) => e.id == entry.id);
      if (i >= 0) {
        final localAt = _entries[i].updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final remoteAt = entry.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (remoteAt.isBefore(localAt)) continue;
        _entries[i] = entry;
      } else {
        _entries.add(entry);
      }
      await _repo.upsertEntry(entry);
    }
    notifyListeners();
  }

  /// Clears everything on this device except the anonymous id and the
  /// appearance choice, which belong to the phone rather than the account.
  Future<void> signOutLocal() async {
    _entries.clear();
    _outbox.clear();
    _events.clear();
    final anon = _meta['anon_id'];
    final appearance = _meta['appearance'];
    await _repo.wipe();
    _meta.clear();
    _babyName = 'My baby';
    _babyId = const Uuid().v4();
    _babyPhoto = null;
    await _repo.setMeta('baby_id', _babyId);
    await _repo.setMeta('baby_name', _babyName);
    if (anon != null) await _putMeta('anon_id', anon);
    if (appearance != null) await _putMeta('appearance', appearance);
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

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
