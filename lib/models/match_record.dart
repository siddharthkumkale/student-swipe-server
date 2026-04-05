import 'package:cloud_firestore/cloud_firestore.dart';

/// A match between the current user and another user (mutual like).
class MatchRecord {
  final String otherUid;
  final String name;
  final String? photoUrl;
  final DateTime matchedAt;

  const MatchRecord({
    required this.otherUid,
    required this.name,
    this.photoUrl,
    required this.matchedAt,
  });

  factory MatchRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['matchedAt'] as Timestamp?;
    return MatchRecord(
      otherUid: doc.id,
      name: data['name'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      matchedAt: ts?.toDate() ?? DateTime.now(),
    );
  }
}
