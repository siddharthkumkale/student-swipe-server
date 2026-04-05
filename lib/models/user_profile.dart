import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for Firestore users collection.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String university;
  final String course;
  final String year;
  final String bio;
  final List<String> skills;
  final String? photoUrl;
  final List<String> additionalPhotos;
  final String? lookingFor;
  final DateTime? createdAt;

  /// When true, backend treats this user as an AI bot (auto-match on like + Groq replies).
  /// Set only in Firestore for dedicated bot accounts; never enable on real users without consent.
  final bool isAiBot;

  /// Optional extra instructions for the AI system prompt (Firestore only).
  final String? aiPersona;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.university,
    required this.course,
    required this.year,
    required this.bio,
    required this.skills,
    this.photoUrl,
    this.additionalPhotos = const [],
    this.lookingFor,
    this.createdAt,
    this.isAiBot = false,
    this.aiPersona,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final List<String> additional =
        List<String>.from(data['additionalPhotos'] as List? ?? const []);
    return UserProfile(
      uid: data['uid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      university: data['university'] as String? ?? '',
      course: data['course'] as String? ?? '',
      year: data['year'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      skills: List<String>.from(data['skills'] as List? ?? []),
      photoUrl: data['photoUrl'] as String?,
      additionalPhotos: additional,
      lookingFor: data['lookingFor'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isAiBot: data['isAiBot'] == true,
      aiPersona: data['aiPersona'] as String?,
    );
  }

  /// When [deleteMainPhotoIfEmpty] is true and there is no main photo URL, writes
  /// [FieldValue.delete] for `photoUrl` so Firestore clears it. Otherwise omits
  /// `photoUrl` when empty so merge preserves an existing photo (e.g. profile setup).
  Map<String, dynamic> toMap({bool deleteMainPhotoIfEmpty = false}) {
    final map = <String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'university': university,
      'course': course,
      'year': year,
      'bio': bio,
      'skills': skills,
      'additionalPhotos': additionalPhotos,
      if (lookingFor != null && lookingFor!.isNotEmpty) 'lookingFor': lookingFor,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      map['photoUrl'] = photoUrl;
    } else if (deleteMainPhotoIfEmpty) {
      map['photoUrl'] = FieldValue.delete();
    }
    if (isAiBot) {
      map['isAiBot'] = true;
      if (aiPersona != null && aiPersona!.isNotEmpty) {
        map['aiPersona'] = aiPersona;
      }
    }
    return map;
  }
}
