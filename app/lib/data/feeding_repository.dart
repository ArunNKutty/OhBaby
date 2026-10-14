import 'dart:typed_data';

import '../models/entry.dart';

class RepoSnapshot {
  const RepoSnapshot({
    required this.entries,
    required this.babyName,
    required this.babyId,
    required this.meta,
    required this.outbox,
    this.babyPhoto,
  });

  final List<Entry> entries;
  final String babyName;
  final String babyId;
  final Map<String, String> meta;
  final Map<String, String> outbox;
  final Uint8List? babyPhoto;
}

/// Local log. The UI talks to [FeedingStore], which talks to this.
abstract class FeedingRepository {
  Future<RepoSnapshot> load();
  Future<void> upsertEntry(Entry entry);
  Future<void> deleteEntry(String id);
  Future<void> setMeta(String key, String value);
  Future<void> removeMeta(String key);
  Future<void> setOutbox(String entryId, String op);
  Future<void> removeOutbox(String entryId);

  /// Device-only files, such as the baby's photo. Null removes it.
  Future<void> setBlob(String key, Uint8List? data);
  Future<void> wipe();
}
