import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Calls your Render (or other) Node service for AI bot match + chat.
///
/// Build/run with:
/// `flutter run --dart-define=AI_BOT_BASE_URL=https://YOUR-SERVICE.onrender.com`
///
/// Omit the trailing slash. If unset, all methods no-op (AI bots disabled).
class AiBotBridge {
  AiBotBridge._();
  static final AiBotBridge instance = AiBotBridge._();

  static const String _baseUrl = String.fromEnvironment(
    'AI_BOT_BASE_URL',
    defaultValue: '',
  );

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _u(String path) {
    final b = _baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$b$path');
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
