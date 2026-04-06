import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/match_record.dart';
import '../models/user_profile.dart';

/// Service for Firestore user profile operations.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  final _firestore = FirebaseFirestore.instance;
  static const _usersCollection = 'users';
  static const _swipesSubcollection = 'swipes';
  static const _matchesSubcollection = 'matches';
  static const _blockedSubcollection = 'blocked';

  /// Save or update user profile. Uses merge so existing fields are not lost.
  ///
  /// Set [deleteMainPhotoIfEmpty] when intentionally removing the main photo from
  /// Firestore; otherwise an empty [UserProfile.photoUrl] leaves the field unchanged.
  Future<void> saveProfile(UserProfile profile, {bool deleteMainPhotoIfEmpty = false}) async {
    await _firestore
        .collection(_usersCollection)
        .doc(profile.uid)
        .set(profile.toMap(deleteMainPhotoIfEmpty: deleteMainPhotoIfEmpty), SetOptions(merge: true));
  }

  /// Get profile by uid.
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (doc.exists) return UserProfile.fromFirestore(doc);
    return null;
  }

  /// Real-time stream of a user's profile.
  Stream<DocumentSnapshot> profileStream(String uid) {
    return _firestore.collection(_usersCollection).doc(uid).snapshots();
  }

  /// All user profiles (for maps / stats). Requires sign-in; same read rules as Discover.
  Stream<List<UserProfile>> allProfilesStream() {
    return _firestore.collection(_usersCollection).snapshots().map(
          (snapshot) => snapshot.docs.map((d) => UserProfile.fromFirestore(d)).toList(),
        );
  }

  /// Stream of profiles to swipe (excludes current user, already-swiped users, and blocked users).
  Stream<List<UserProfile>> getSwipeableProfiles(String currentUid) {
    return _firestore.collection(_usersCollection).snapshots().asyncMap(
      (snapshot) async {
        final swipedIds = await _getSwipedUserIds(currentUid);
        final blockedIds = await _getBlockedUserIds(currentUid);
        return snapshot.docs
            .where((doc) =>
                doc.id != currentUid &&
                !swipedIds.contains(doc.id) &&
                !blockedIds.contains(doc.id))
            .map((doc) => UserProfile.fromFirestore(doc))
            .toList();
      },
    );
  }

  Future<Set<String>> _getSwipedUserIds(String uid) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_swipesSubcollection)
        .get();
    return snapshot.docs.map((d) => d.id).toSet();
  }

  Future<Set<String>> _getBlockedUserIds(String uid) async {
    final snapshot = await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_blockedSubcollection)
        .get();
    return snapshot.docs.map((d) => d.id).toSet();
  }

  /// Record a swipe (like or pass).
  Future<void> recordSwipe({
    required String fromUid,
    required String toUid,
    required bool isLike,
  }) async {
    await _firestore
        .collection(_usersCollection)
        .doc(fromUid)
        .collection(_swipesSubcollection)
        .doc(toUid)
        .set({
      'action': isLike ? 'like' : 'pass',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Check if there's a mutual like (match).
  Future<bool> isMatch(String uidA, String uidB) async {
    final aLikesB = await _firestore
        .collection(_usersCollection)
        .doc(uidA)
        .collection(_swipesSubcollection)
        .doc(uidB)
        .get();
    final bLikesA = await _firestore
        .collection(_usersCollection)
        .doc(uidB)
        .collection(_swipesSubcollection)
        .doc(uidA)
        .get();

    final aLiked = aLikesB.exists && (aLikesB.data()?['action'] == 'like');
    final bLiked = bLikesA.exists && (bLikesA.data()?['action'] == 'like');
    return aLiked && bLiked;
  }

  /// Write a match for both users (call when isMatch is true). Real-time listeners will see new matches.
  Future<void> recordMatch(String uid1, UserProfile profile2) async {
    final now = FieldValue.serverTimestamp();
    final matchData = {
      'matchedAt': now,
      'name': profile2.name,
      if (profile2.photoUrl != null) 'photoUrl': profile2.photoUrl,
    };
    await _firestore
        .collection(_usersCollection)
        .doc(uid1)
        .collection(_matchesSubcollection)
        .doc(profile2.uid)
        .set(matchData);
    final profile1 = await getProfile(uid1);
    final otherData = {
      'matchedAt': now,
      'name': profile1?.name ?? 'Someone',
      if (profile1?.photoUrl != null) 'photoUrl': profile1!.photoUrl,
    };
    await _firestore
        .collection(_usersCollection)
        .doc(profile2.uid)
        .collection(_matchesSubcollection)
        .doc(uid1)
        .set(otherData);
  }

  /// Remove a match for both users (unmatch). Deletes from both users' matches subcollections.
  Future<void> removeMatch(String uid, String otherUid) async {
    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_matchesSubcollection)
        .doc(otherUid)
        .delete();
    await _firestore
        .collection(_usersCollection)
        .doc(otherUid)
        .collection(_matchesSubcollection)
        .doc(uid)
        .delete();
  }

  /// Block another user: add to blocked list and remove any existing match.
  Future<void> blockUser(String uid, String otherUid) async {
    final batch = _firestore.batch();

    final blockedRef = _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_blockedSubcollection)
        .doc(otherUid);
    batch.set(blockedRef, {
      'blockedAt': FieldValue.serverTimestamp(),
    });

    final myMatchRef = _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_matchesSubcollection)
        .doc(otherUid);
    final otherMatchRef = _firestore
        .collection(_usersCollection)
        .doc(otherUid)
        .collection(_matchesSubcollection)
        .doc(uid);
    batch.delete(myMatchRef);
    batch.delete(otherMatchRef);

    await batch.commit();
  }

  /// Call when the user opens the Notifications tab so the match badge can clear.
  Future<void> markNotificationsTabVisited(String uid) async {
    await _firestore.collection(_usersCollection).doc(uid).set(
      {'notificationsLastVisitedAt': Timestamp.fromDate(DateTime.now())},
      SetOptions(merge: true),
    );
  }

  /// Matches newer than the last time the user opened the Notifications tab.
  int countNewMatchNotifications(List<MatchRecord> matches, DateTime? lastVisitedAt) {
    if (lastVisitedAt == null) return matches.length;
    return matches.where((m) => m.matchedAt.isAfter(lastVisitedAt)).length;
  }

  /// Real-time stream of the current user's matches (for Notifications screen).
  Stream<List<MatchRecord>> matchesStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_matchesSubcollection)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((d) => MatchRecord.fromFirestore(d)).toList();
          list.sort((a, b) => b.matchedAt.compareTo(a.matchedAt));
          return list;
        });
  }
}
