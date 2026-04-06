/// Live fields from the chat document (typing, last activity).
class ChatLiveMeta {
  final DateTime? lastMessageAt;
  final bool otherTyping;
  final String? lastSenderId;

  const ChatLiveMeta({
    this.lastMessageAt,
    this.otherTyping = false,
    this.lastSenderId,
  });
}
