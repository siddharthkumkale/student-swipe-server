import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  final _firestore = FirebaseFirestore.instance;
  static const _reportsCollection = 'reports';

  Future<void> submitReport({
    required String reporterUid,
    required String reportedUid,
    required String reason,
    String? details,
  }) async {
    await _firestore.collection(_reportsCollection).add({
      'reporterUid': reporterUid,
      'reportedUid': reportedUid,
      'reason': reason,
      if (details != null && details.isNotEmpty) 'details': details,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

