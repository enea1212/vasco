import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves accepted co-author display names from user docs with a global
/// in-memory cache shared across screens.
class CoAuthorNames {
  CoAuthorNames._();

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _inflight = {};

  static Future<List<String>> resolve(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final futures = userIds.map(_resolveOne).toList();
    return Future.wait(futures);
  }

  static Future<String> _resolveOne(String uid) {
    final cached = _cache[uid];
    if (cached != null) return Future.value(cached);
    final inflight = _inflight[uid];
    if (inflight != null) return inflight;

    final future = _fetchName(uid).whenComplete(() {
      _inflight.remove(uid);
    });
    _inflight[uid] = future;
    return future;
  }

  static Future<String> _fetchName(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      final name = (data?['displayName'] as String?) ??
          (data?['display_name'] as String?) ??
          'User';
      _cache[uid] = name;
      return name;
    } catch (_) {
      return 'User';
    }
  }

  /// Formats "Creator & CoAuthor1, CoAuthor2" or "Creator & 2 others"
  /// depending on the number of co-authors.
  static String format(String creator, List<String> coAuthorNames) {
    if (coAuthorNames.isEmpty) return creator;
    if (coAuthorNames.length == 1) {
      return '$creator & ${coAuthorNames[0]}';
    }
    if (coAuthorNames.length == 2) {
      return '$creator & ${coAuthorNames[0]}, ${coAuthorNames[1]}';
    }
    return '$creator & ${coAuthorNames[0]} +${coAuthorNames.length - 1}';
  }
}
