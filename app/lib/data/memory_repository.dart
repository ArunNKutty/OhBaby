import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../models/entry.dart';
import 'feeding_repository.dart';

/// In-memory log used by widget tests and as a fallback shape for the store.
class MemoryFeedingRepository implements FeedingRepository {
  MemoryFeedingRepository({String? babyId}) : babyId = babyId ?? const Uuid().v4();

  final List<Entry> _entries = [];
  String babyName = 'My baby';
  String babyId;
  final Map<String, String> meta = {};
  final Map<String, String> outbox = {};
  final Map<String, Uint8List> blobs = {};

  @override
  Future<RepoSnapshot> load() async => RepoSnapshot(
        entries: List.of(_entries),
        babyName: meta['baby_name'] ?? babyName,
        babyId: meta['baby_id'] ?? babyId,
        meta: Map.of(meta),
        outbox: Map.of(outbox),
        babyPhoto: blobs['baby_photo'],
      );

  @override
  Future<void> upsertEntry(Entry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i >= 0) {
      _entries[i] = entry;
    } else {
      _entries.add(entry);
    }
  }

  @override
  Future<void> deleteEntry(String id) async => _entries.removeWhere((e) => e.id == id);

  @override
  Future<void> setMeta(String key, String value) async => meta[key] = value;

  @override
  Future<void> removeMeta(String key) async => meta.remove(key);

  @override
  Future<void> setOutbox(String entryId, String op) async => outbox[entryId] = op;

  @override
  Future<void> removeOutbox(String entryId) async => outbox.remove(entryId);

  @override
  Future<void> setBlob(String key, Uint8List? data) async {
    if (data == null) {
      blobs.remove(key);
    } else {
      blobs[key] = data;
    }
  }

  @override
  Future<void> wipe() async {
    _entries.clear();
    outbox.clear();
    meta.clear();
    blobs.clear();
    babyName = 'My baby';
  }
}
