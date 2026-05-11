import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SwipeRemoteDatasource {
  const SwipeRemoteDatasource(this._db, this._functions);
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  // ─── Candidates ───────────────────────────────────────────────────────────

  /// Calls the `getRecommendations` Cloud Function and returns the raw list.
  /// The function handles all geo/preference filtering server-side.
  Future<List<Map<String, dynamic>>> getCandidates(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    final callable = _functions.httpsCallable('getRecommendations');
    final result = await callable.call(preferences.isEmpty ? null : preferences);
    final data = result.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  // ─── Swipe / match ────────────────────────────────────────────────────────

  /// Calls the `recordSwipe` Cloud Function.
  /// Returns true when the server signals a mutual match.
  Future<bool> recordSwipe(Map<String, dynamic> swipeData) async {
    final callable = _functions.httpsCallable('recordSwipe');
    final result = await callable.call(swipeData);
    final data = result.data;
    if (data is Map) {
      return (Map<String, dynamic>.from(data))['matched'] == true;
    }
    return false;
  }

  /// Full swipe result including matchedUser and conversationId when matched.
  Future<Map<String, dynamic>> recordSwipeFull(
    Map<String, dynamic> swipeData,
  ) async {
    final callable = _functions.httpsCallable('recordSwipe');
    final result = await callable.call(swipeData);
    final data = result.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  // ─── Matches ──────────────────────────────────────────────────────────────

  /// Live count / list stream for the `matches` collection.
  Stream<List<Map<String, dynamic>>> watchMatches(String userId) {
    return _db
        .collection('matches')
        .where('users', arrayContains: userId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// One-shot fetch via `getMyMatches` Cloud Function (used by MyMatchesScreen).
  Future<List<Map<String, dynamic>>> getMyMatches() async {
    final callable = _functions.httpsCallable('getMyMatches');
    final result = await callable.call();
    final data = result.data is Map
        ? Map<String, dynamic>.from(result.data as Map)
        : <String, dynamic>{};
    final matches = data['matches'];
    if (matches is! List) return [];
    return matches
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
