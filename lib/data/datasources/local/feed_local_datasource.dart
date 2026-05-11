import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local Hive cache for the location_photos feed.
///
/// Timestamps are serialised as `{'__timestampMillis': int}` so they survive
/// round-trips through Hive without importing Firestore in the UI layer.
class FeedLocalDatasource {
  static const String boxName = 'feed_cache';
  static const String _postsKey = 'posts';

  Box get _box => Hive.box(boxName);

  // ─── Read ─────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>>? getCachedFeed(String userId) {
    final raw = _box.get('${userId}_$_postsKey') ?? _box.get(_postsKey);
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((item) => _decodeMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ─── Write ────────────────────────────────────────────────────────────────

  Future<void> cacheFeed(
    String userId,
    List<Map<String, dynamic>> posts,
  ) async {
    final encoded = posts.map(_encodeMap).toList();
    await _box.put('${userId}_$_postsKey', encoded);
  }

  /// Convenience method used by FeedCacheService-compatible callers:
  /// accepts raw Firestore docs already mapped to `Map<String,dynamic>`.
  Future<void> cacheFeedFromSnapshot(
    String userId,
    List<Map<String, dynamic>> rawDocs,
  ) async {
    final encoded = rawDocs.map(_encodeMap).toList();
    await _box.put('${userId}_$_postsKey', encoded);
  }

  Future<void> clearCache(String userId) async {
    await _box.delete('${userId}_$_postsKey');
  }

  // ─── Encode / decode (Timestamp <-> plain Map) ────────────────────────────

  Map<String, dynamic> _encodeMap(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _encodeValue(v)));
  }

  dynamic _encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestampMillis': value.millisecondsSinceEpoch};
    }
    if (value is Map) {
      return value.map(
        (k, v) => MapEntry(k.toString(), _encodeValue(v)),
      );
    }
    if (value is List) return value.map(_encodeValue).toList();
    return value;
  }

  Map<String, dynamic> _decodeMap(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _decodeValue(v)));
  }

  dynamic _decodeValue(dynamic value) {
    if (value is Map) {
      final millis = value['__timestampMillis'];
      if (millis is int) {
        return Timestamp.fromMillisecondsSinceEpoch(millis);
      }
      return value.map(
        (k, v) => MapEntry(k.toString(), _decodeValue(v)),
      );
    }
    if (value is List) return value.map(_decodeValue).toList();
    return value;
  }
}
