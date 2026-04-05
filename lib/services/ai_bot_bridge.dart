import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_service_config.dart';
import 'auth_service.dart';

/// Calls your Render service for AI bots (match + chat + demo profile seed).
///
/// Uses [kDefaultAiBotBaseUrl] so a normal `flutter run` works. Override with:
/// `--dart-define=AI_BOT_BASE_URL=https://other.onrender.com`
class AiBotBridge {
  AiBotBridge._();
  static final AiBotBridge instance = AiBotBridge._();

  static const String _fromDefine = String.fromEnvironment(
    'AI_BOT_BASE_URL',
    defaultValue: '',
  );

  static String get _resolvedBase {
    final fromEnv = _fromDefine.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/$'), '');
    }
    return kDefaultAiBotBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
  }

  bool get isConfigured => _resolvedBase.isNotEmpty;

  Uri _u(String path) {
    return Uri.parse('${_resolvedBase}$path');
  }

  /// Creates demo AI user docs in Firestore (idempotent). Safe to call every app open.
  Future<void> seedDemoAiProfiles() async {
    if (!isConfigured) return;
    final token = await AuthService.instance.getIdToken();
    if (token == null) return;
    try {
      final res = await http
          .post(
            _u('/api/seed-demo-profiles'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && kDebugMode) {
        debugPrint('AiBotBridge.seedDemo: ${res.statusCode} ${res.body}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AiBotBridge.seedDemo failed: $e\n$st');
      }
    }
  }

  Future<void> ensureMatchAfterLike({required String botUid}) async {
    if (!isConfigured) return;
    final token = await AuthService.instance.getIdToken();
    if (token == null) return;
    try {
      final res = await http
          .post(
            _u('/api/ensure-match'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'botUid': botUid}),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 && kDebugMode) {
        debugPrint('AiBotBridge.ensureMatch: ${res.statusCode} ${res.body}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AiBotBridge.ensureMatch failed: $e\n$st');
      }
    }
  }

  Future<void> requestChatReply({required String botUid}) async {
    if (!isConfigured) return;
    final token = await AuthService.instance.getIdToken();
    if (token == null) return;
    try {
      final res = await http
          .post(
            _u('/api/chat-reply'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'botUid': botUid}),
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode != 200 && kDebugMode) {
        debugPrint('AiBotBridge.chatReply: ${res.statusCode} ${res.body}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AiBotBridge.chatReply failed: $e\n$st');
      }
    }
  }
}
