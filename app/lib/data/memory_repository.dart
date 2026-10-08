import 'package:uuid/uuid.dart';

import '../models/feeding.dart';
import 'feeding_repository.dart';

/// In-memory log used by widget tests and as a fallback shape for the store.
class MemoryFeedingRepository implements FeedingRepository {
  MemoryFeedingRepository({String? babyId})
      : babyId = babyId ?? const Uuid().v4();

  final List<Feeding> _feedings = [];
  String babyName = 'My baby';
  String babyId;
  final Map<String, String> meta = {};
  final Map<String, String> outbox = {};

  @override
  Future<RepoSnapshot> load() async => RepoSnapshot(
        feedings: List.of(_feedings),
        babyName: babyName,
        babyId: babyId,
        meta: Map.of(meta),
        outbox: Map.of(outbox),
      );

  @override
  Future<void> upsertFeeding(Feeding feeding) async {
    final i = _feedings.indexWhere((f) => f.id == feeding.id);
    if (i >= 0) {
      _feedings[i] = feeding;
    } else {
      _feedings.add(feeding);
    }
  }

  @override
  Future<void> deleteFeeding(String id) async {
    _feedings.removeWhere((f) => f.id == id);
  }

  @override
  Future<void> setMeta(String key, String value) async {
    meta[key] = value;
  }

  @override
  Future<void> removeMeta(String key) async {
    meta.remove(key);
  }

  @override
  Future<void> setOutbox(String feedingId, String op) async {
    outbox[feedingId] = op;
  }

  @override
  Future<void> removeOutbox(String feedingId) async {
    outbox.remove(feedingId);
  }

  @override
  Future<void> replaceAll(List<Feeding> feedings) async {
    _feedings
      ..clear()
      ..addAll(feedings);
  }

  @override
  Future<void> wipe() async {
    _feedings.clear();
    outbox.clear();
    meta.clear();
    babyName = 'My baby';
  }
}
