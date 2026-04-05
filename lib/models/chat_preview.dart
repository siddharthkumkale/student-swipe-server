/// Summary of a chat for the list + unread indicator.
class ChatPreview {
  final String chatId;
  final String otherUid;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final List<String> readBy;
  final bool otherTyping;

  const ChatPreview({
    required this.chatId,
    required this.otherUid,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastSenderId,
    this.readBy = const [],
    this.otherTyping = false,
  });

  bool isUnread(String currentUid) =>
      lastSenderId != null &&
      lastSenderId != currentUid &&
      lastSenderId!.isNotEmpty &&
      !readBy.contains(currentUid);
}
