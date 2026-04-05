import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';
import '../models/chat_preview.dart';
import 'ai_bot_bridge.dart';
import 'profile_service.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final _firestore = FirebaseFirestore.instance;
  static const _chatsCollection = 'chats';
  static const _messagesSubcollection = 'messages';

  /// Deterministic chat id for two users (sorted so same for both).
  static String chatId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Ensure chat doc exists and return chat id.
  Future<String> getOrCreateChat(String uid1, String uid2) async {
    final cid = chatId(uid1, uid2);
    final ref = _firestore.collection(_chatsCollection).doc(cid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'participants': [uid1, uid2],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': null,
      });
    }
    return cid;
  }

  /// Send a message. Creates chat if needed and updates chat doc for list ordering + unread.
  Future<void> sendMessage({
    required String senderUid,
    required String otherUid,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final cid = await getOrCreateChat(senderUid, otherUid);
    final trimmed = text.trim();
    await _firestore
        .collection(_chatsCollection)
        .doc(cid)
        .collection(_messagesSubcollection)
        .add({
      'senderId': senderUid,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection(_chatsCollection).doc(cid).update({
      'lastMessageText': trimmed.length > 80 ? '${trimmed.substring(0, 80)}...' : trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': senderUid,
      'readBy': [senderUid],
    });

    final otherProfile = await ProfileService.instance.getProfile(otherUid);
    if (otherProfile?.isAiBot == true) {
      await AiBotBridge.instance.requestChatReply(botUid: otherUid);
    }
  }

  /// Real-time stream of the current user's chats (for list + new-message badge).
  Stream<List<ChatPreview>> myChatsStream(String uid) {
    return _firestore
        .collection(_chatsCollection)
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final d = doc.data();
        final participants = List<String>.from(d['participants'] as List? ?? []);
        final otherUid = participants.length == 2
            ? participants.firstWhere((e) => e != uid, orElse: () => '')
            : '';
        final ts = d['lastMessageAt'] as Timestamp?;
        final readBy = List<String>.from(d['readBy'] as List? ?? []);
        final typingMap = (d['typing'] as Map<String, dynamic>?) ?? {};
        final otherTyping = otherUid.isNotEmpty && (typingMap[otherUid] == true);
        return ChatPreview(
          chatId: doc.id,
          otherUid: otherUid,
          lastMessageText: d['lastMessageText'] as String?,
          lastMessageAt: ts?.toDate(),
          lastSenderId: d['lastSenderId'] as String?,
          readBy: readBy,
          otherTyping: otherTyping,
        );
      }).toList();
    });
  }

  /// Real-time stream of messages for a chat (between current user and other).
  Stream<List<ChatMessage>> messagesStream(String currentUid, String otherUid) {
    final cid = chatId(currentUid, otherUid);
    return _firestore
        .collection(_chatsCollection)
        .doc(cid)
        .collection(_messagesSubcollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromFirestore(d)).toList());
  }

  /// Mark latest message in chat as read by the given user.
  Future<void> markChatRead({
    required String currentUid,
    required String otherUid,
  }) async {
    final cid = chatId(currentUid, otherUid);
    await _firestore.collection(_chatsCollection).doc(cid).update({
      'readBy': FieldValue.arrayUnion([currentUid]),
    });
  }

  /// Update typing indicator for the current user in a chat.
  Future<void> setTyping({
    required String currentUid,
    required String otherUid,
    required bool isTyping,
  }) async {
    final cid = chatId(currentUid, otherUid);
    await _firestore.collection(_chatsCollection).doc(cid).set(
      {
        'typing': {currentUid: isTyping},
      },
      SetOptions(merge: true),
    );
  }
}
