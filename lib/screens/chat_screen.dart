import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_message.dart';
import '../models/match_record.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import 'match_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String otherUid;
  final String otherName;

  const ChatScreen({super.key, required this.otherUid, required this.otherName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _chatReady = false;
  String? _chatError;
  bool _isTyping = false;
  ChatViewTheme _chatTheme = ChatViewTheme.aurora;

  @override
  void initState() {
    super.initState();
    _ensureChatExists();
  }

  Future<void> _ensureChatExists() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ChatService.instance.getOrCreateChat(uid, widget.otherUid);
      if (mounted) setState(() { _chatReady = true; _chatError = null; });
    } catch (e) {
      if (mounted) setState(() { _chatError = e.toString(); _chatReady = true; });
    }
  }

  @override
  void dispose() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      ChatService.instance.setTyping(
        currentUid: uid,
        otherUid: widget.otherUid,
        isTyping: false,
      );
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    _textController.clear();
    if (_isTyping) {
      _setTyping(false);
    }
    try {
      await ChatService.instance.sendMessage(
        senderUid: uid,
        otherUid: widget.otherUid,
        text: text,
      );
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        _textController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: !_chatReady
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                    : _chatError != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 28),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: TinderStyle.border),
                                  boxShadow: [TinderStyle.cardShadow()],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Couldn\'t open chat',
                                      style: TinderStyle.cardTitle(),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _chatError!,
                                      style: TinderStyle.cardSubtitle(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : StreamBuilder<List<ChatMessage>>(
                            stream: ChatService.instance.messagesStream(uid, widget.otherUid),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 28),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: TinderStyle.border),
                                        boxShadow: [TinderStyle.cardShadow()],
                                      ),
                                      child: Text(
                                        'Couldn\'t load messages',
                                        style: TinderStyle.bodyCard(),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(color: AppTheme.accent),
                                );
                              }

                              // Mark chat as read whenever we show messages.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ChatService.instance.markChatRead(
                                  currentUid: uid,
                                  otherUid: widget.otherUid,
                                );
                              });

                              return ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final msg = messages[index];
                                  final isMe = msg.senderId == uid;
                                  return _MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    theme: _chatTheme,
                                  );
                                },
                              );
                            },
                          ),
              ),
              _buildInput(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TinderStyle.border),
          boxShadow: [TinderStyle.cardShadow()],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF3F4F6),
                foregroundColor: TinderStyle.ink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherName,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: TinderStyle.ink,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chat',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TinderStyle.subtle,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: TinderStyle.border),
            ),
            icon: Icon(Icons.more_vert_rounded, color: TinderStyle.ink),
            onSelected: (value) {
              switch (value) {
                case 'view_profile':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => MatchDetailScreen(
                        match: MatchRecord(
                          otherUid: widget.otherUid,
                          name: widget.otherName,
                          photoUrl: null,
                          matchedAt: DateTime.now(),
                        ),
                      ),
                    ),
                  );
                  break;
                case 'chat_theme':
                  _openThemePicker();
                  break;
                default:
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'chat_theme',
                child: Text('Chat appearance', style: TinderStyle.bodyCard()),
              ),
              PopupMenuItem(
                value: 'view_profile',
                child: Text('View profile', style: TinderStyle.bodyCard()),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    final inputBg = _chatTheme == ChatViewTheme.light
        ? const Color(0xFFF3F4F6)
        : Colors.white.withValues(alpha: 0.08);
    final inputText = _chatTheme == ChatViewTheme.light ? Colors.black87 : Colors.white;
    final inputHint = _chatTheme == ChatViewTheme.light ? Colors.black45 : Colors.white.withValues(alpha: 0.5);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TinderStyle.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: TextStyle(color: inputHint),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              style: GoogleFonts.outfit(
                color: inputText,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 4,
              minLines: 1,
              onChanged: _handleChanged,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _handleChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText && !_isTyping) {
      _setTyping(true);
    } else if (!hasText && _isTyping) {
      _setTyping(false);
    }
  }

  void _setTyping(bool value) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isTyping = value);
    ChatService.instance.setTyping(
      currentUid: uid,
      otherUid: widget.otherUid,
      isTyping: value,
    );
  }

  void _openThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: TinderStyle.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: TinderStyle.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Chat appearance',
                style: TinderStyle.cardTitle().copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              _themeTile(ChatViewTheme.aurora, 'Aurora (default)', 'Soft dark with red accent'),
              _themeTile(ChatViewTheme.midnight, 'Midnight', 'Higher contrast dark bubbles'),
              _themeTile(ChatViewTheme.light, 'Light', 'Bright incoming bubbles'),
            ],
          ),
        );
      },
    );
  }

  Widget _themeTile(ChatViewTheme theme, String title, String subtitle) {
    final selected = _chatTheme == theme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: TinderStyle.cardTitle().copyWith(fontSize: 15)),
      subtitle: Text(subtitle, style: TinderStyle.cardSubtitle().copyWith(fontSize: 13)),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent) : null,
      onTap: () {
        setState(() => _chatTheme = theme);
        Navigator.of(context).pop();
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final ChatViewTheme theme;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _bubbleColors(theme, isMe);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(color: colors.$2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(color: colors.$3, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: colors.$3.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  (Color, Color, Color) _bubbleColors(ChatViewTheme theme, bool isMe) {
    switch (theme) {
      case ChatViewTheme.midnight:
        return isMe
            ? (const Color(0xFFDC2626), const Color(0xFFFCA5A5), Colors.white)
            : (const Color(0xFF111827), const Color(0xFF374151), Colors.white);
      case ChatViewTheme.light:
        return isMe
            ? (const Color(0xFFEF4444), const Color(0xFFFDA4AF), Colors.white)
            : (const Color(0xFFFFFFFF), const Color(0xFFE5E7EB), const Color(0xFF111827));
      case ChatViewTheme.aurora:
        return isMe
            ? (AppTheme.accent.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.12), Colors.white)
            : (AppTheme.card.withValues(alpha: 0.8), Colors.white.withValues(alpha: 0.08), Colors.white);
    }
  }
}

enum ChatViewTheme { aurora, midnight, light }
