import '../models/feeding.dart';

class RepoSnapshot {
  const RepoSnapshot({
    required this.feedings,
    required this.babyName,
    required this.babyId,
    required this.meta,
    required this.outbox,
  });

  final List<Feeding> feedings;
  final String babyName;
  final String babyId;
  final Map<String, String> meta;
  final Map<String, String> outbox;
}

/// Local feeding log. The UI talks to [FeedingStore], which talks to this.
abstract class FeedingRepository {
  Future<RepoSnapshot> load();
  Future<void> upsertFeeding(Feeding feeding);
  Future<void> deleteFeeding(String id);
  Future<void> setMeta(String key, String value);
  Future<void> removeMeta(String key);
  Future<void> setOutbox(String feedingId, String op);
  Future<void> removeOutbox(String feedingId);
  Future<void> replaceAll(List<Feeding> feedings);
  Future<void> wipe();
}
