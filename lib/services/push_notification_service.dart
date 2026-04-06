import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import '../models/chat_preview.dart';
import '../models/match_record.dart';
import 'chat_service.dart';
import 'profile_service.dart';

const _androidChannelId = 'student_swipe_alerts';
const _androidChannelName = 'Student Swipe';

/// Top-level handler for FCM when the app is in background / terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Local notifications + FCM token sync. While the app is running, also listens
/// to Firestore chats/matches and surfaces alerts (for instant feedback).
/// For notifications when the app is fully closed, send FCM from your backend
/// (e.g. Cloud Function on new message) using the stored [fcmToken] on the user doc.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fm = FirebaseMessaging.instance;

  bool _localReady = false;
  int _notifId = 0;
  StreamSubscription<List<ChatPreview>>? _chatsSub;
  StreamSubscription<List<MatchRecord>>? _matchesSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  List<ChatPreview>? _lastChats;
  int? _lastMatchCount;
  String? _attachedUid;

  Future<void> ensureLocalNotificationsReady() async {
    if (_localReady) return;
    if (kIsWeb) {
      _localReady = true;
      return;
    }
    // Plugin requires full platform settings for Windows/macOS/Linux; mobile only here.
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _localReady = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        importance: Importance.high,
        playSound: true,
      ),
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      await androidPlugin?.requestNotificationsPermission();
    }

    _localReady = true;
  }

  Future<void> attachToUser(String uid) async {
    if (uid == _attachedUid) return;
    await detachUser();
    _attachedUid = uid;

    await ensureLocalNotificationsReady();

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await _fm.requestPermission(alert: true, badge: true, sound: true);
        final token = await _fm.getToken();
        if (token != null) {
          await _saveToken(uid, token);
        }
        await _tokenRefreshSub?.cancel();
        _tokenRefreshSub = _fm.onTokenRefresh.listen((t) => _saveToken(uid, t));

        await _foregroundSub?.cancel();
        _foregroundSub = FirebaseMessaging.onMessage.listen(_onForegroundFcm);
      } catch (e, st) {
        debugPrint('PushNotificationService FCM setup: $e\n$st');
      }
    }

    _lastChats = null;
    _chatsSub = ChatService.instance.myChatsStream(uid).listen((list) {
      if (_lastChats == null) {
        _lastChats = list;
        return;
      }
      final prevUnread = _lastChats!.where((p) => p.isUnread(uid)).length;
      final nowUnread = list.where((p) => p.isUnread(uid)).length;
      if (nowUnread > prevUnread) {
        showLocalNotification(
          id: ++_notifId,
          title: 'New message',
          body: 'Open Messages from Discover to read your chat.',
        );
      }
      _lastChats = list;
    });

    _lastMatchCount = null;
    _matchesSub = ProfileService.instance.matchesStream(uid).listen((matches) {
      if (_lastMatchCount == null) {
        _lastMatchCount = matches.length;
        return;
      }
      if (matches.length > _lastMatchCount!) {
        showLocalNotification(
          id: ++_notifId,
          title: 'New match!',
          body: 'You have a new mutual like. Check Notifications.',
        );
      }
      _lastMatchCount = matches.length;
    });
  }

  Future<void> detachUser() async {
    await _chatsSub?.cancel();
    await _matchesSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    _chatsSub = null;
    _matchesSub = null;
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _lastChats = null;
    _lastMatchCount = null;
    _attachedUid = null;
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e, st) {
      debugPrint('PushNotificationService save token: $e\n$st');
    }
  }

  void _onForegroundFcm(RemoteMessage message) {
    final n = message.notification;
    showLocalNotification(
      id: ++_notifId,
      title: n?.title ?? 'Student Swipe',
      body: n?.body ?? '',
    );
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    if (!_localReady) return;
    const android = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Matches and messages',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: android, iOS: ios),
    );
  }
}
