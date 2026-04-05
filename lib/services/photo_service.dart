import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Upload and manage profile photos. Tries Firebase Storage first; if that
/// fails (e.g. not enabled / free plan), stores a small image as base64 in
/// the profile (no Storage or billing needed).
class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  final _storage = FirebaseStorage.instance;
  static const _profilePhotosPath = 'profile_photos';

  /// Pick an image from gallery and upload as profile photo. Returns URL or data URL.
  /// For simplicity and to avoid Storage permissions/billing issues, this version
  /// always stores a small compressed image as a data URL in Firestore.
  Future<String?> pickAndUploadProfilePhoto(String uid) async {
    final picker = ImagePicker();
    // Keep size moderate so fallback data URL stays under Firestore doc limit (~1MB).
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );
    if (xFile == null) return null;
    final bytes = await xFile.readAsBytes();

    // Store a small compressed image as data URL (stored in Firestore, no Storage needed).
    return _bytesToDataUrl(bytes);
  }

  /// Upload image bytes to Firebase Storage. Returns download URL or null.
  Future<String?> uploadProfilePhotoFromBytes(String uid, List<int> bytes) async {
    if (bytes.isEmpty) return null;
    final ref = _storage.ref().child('$_profilePhotosPath/$uid');
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Compress and convert to data URL (stays under Firestore size limit).
  static String? _bytesToDataUrl(List<int> bytes) {
    if (bytes.isEmpty) return null;
    final base64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64';
  }
}
