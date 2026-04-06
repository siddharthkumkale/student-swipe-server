import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_live_meta.dart';
import '../models/chat_message.dart';
import '../models/match_record.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
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
  bool? _otherIsAiBot;

  @override
  void initState() {
    super.initState();
    _ensureChatExists();
    ProfileService.instance.getProfile(widget.otherUid).then((p) {
      if (mounted) setState(() => _otherIsAiBot = p?.isAiBot == true);
    });
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
              Expanded(
                child: !_chatReady
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAppBar(
                            context,
                            currentUid: uid,
                            meta: null,
                            messages: const [],
                          ),
                          const Expanded(
                            child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                          ),
                        ],
                      )
                    : _chatError != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAppBar(
                                context,
                                currentUid: uid,
                                meta: null,
                                messages: const [],
                              ),
                              Expanded(
                                child: Center(
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
                                ),
                              ),
                            ],
                          )
                        : StreamBuilder<ChatLiveMeta>(
                            stream: ChatService.instance.chatLiveMetaStream(uid, widget.otherUid),
                            builder: (context, metaSnap) {
                              return StreamBuilder<List<ChatMessage>>(
                                stream: ChatService.instance.messagesStream(uid, widget.otherUid),
                                builder: (context, snapshot) {
                                  if (snapshot.hasError) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildAppBar(
                                          context,
                                          currentUid: uid,
                                          meta: metaSnap.data,
                                          messages: const [],
                                        ),
                                        Expanded(
                                          child: Center(
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
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  final messages = snapshot.data ?? [];
                                  if (messages.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        _buildAppBar(
                                          context,
                                          currentUid: uid,
                                          meta: metaSnap.data,
                                          messages: const [],
                                        ),
                                        const Expanded(
                                          child: Center(
                                            child: CircularProgressIndicator(color: AppTheme.accent),
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    ChatService.instance.markChatRead(
                                      currentUid: uid,
                                      otherUid: widget.otherUid,
                                    );
                                  });

                                  final items = _messagesWithDayBreaks(messages);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildAppBar(
                                        context,
                                        currentUid: uid,
                                        meta: metaSnap.data,
                                        messages: messages,
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                                          itemCount: items.length,
                                          itemBuilder: (context, index) {
                                            final item = items[index];
                                            if (item is DateTime) {
                                              return _DateSectionPill(label: _sectionLabelForDay(item));
                                            }
                                            final msg = item as ChatMessage;
                                            final isMe = msg.senderId == uid;
                                            return _MessageBubble(
                                              message: msg,
                                              isMe: isMe,
                                              theme: _chatTheme,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
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

  Widget _buildAppBar(
    BuildContext context, {
    required String currentUid,
    ChatLiveMeta? meta,
    required List<ChatMessage> messages,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TinderStyle.border),
            boxShadow: [TinderStyle.cardShadow()],
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: TinderStyle.ink,
                  padding: const EdgeInsets.all(10),
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherName,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: TinderStyle.ink,
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _buildPresenceSubtitle(
                      currentUid: currentUid,
                      meta: meta,
                      messages: messages,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _showChatOptionsSheet(context),
                icon: Icon(Icons.more_horiz_rounded, color: TinderStyle.ink, size: 24),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(40, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatOptionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: TinderStyle.border),
        ),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: TinderStyle.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.palette_outlined, color: TinderStyle.ink.withValues(alpha: 0.85)),
              title: Text('Chat appearance', style: TinderStyle.bodyCard()),
              onTap: () {
                Navigator.pop(ctx);
                _openThemePicker();
              },
            ),
            ListTile(
              leading: Icon(Icons.person_outline_rounded, color: TinderStyle.ink.withValues(alpha: 0.85)),
              title: Text('View profile', style: TinderStyle.bodyCard()),
              onTap: () {
                Navigator.pop(ctx);
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: TinderStyle.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              cursorColor: AppTheme.accent,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: GoogleFonts.outfit(
                  color: TinderStyle.subtle,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: TinderStyle.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: TinderStyle.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                isDense: true,
              ),
              style: GoogleFonts.outfit(
                color: TinderStyle.ink,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              onChanged: _handleChanged,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _send,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                ),
              ),
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

  List<Object> _messagesWithDayBreaks(List<ChatMessage> messages) {
    final out = <Object>[];
    DateTime? prevDay;
    for (final m in messages) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (prevDay == null || day != prevDay) {
        out.add(day);
        prevDay = day;
      }
      out.add(m);
    }
    return out;
  }

  String _sectionLabelForDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d0 = DateTime(day.year, day.month, day.day);
    if (d0 == today) return 'Today';
    if (d0 == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (day.year == now.year) {
      return '${weekdays[day.weekday - 1]} · ${day.day} ${months[day.month - 1]}';
    }
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  String _lastSeenPhrase(DateTime last) {
    final diff = DateTime.now().difference(last);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final y = DateTime.now().year;
    if (last.year == y) {
      return 'Last seen ${last.day} ${months[last.month - 1]}';
    }
    return 'Last seen ${last.day} ${months[last.month - 1]} ${last.year}';
  }

  Widget _buildPresenceSubtitle({
    required String currentUid,
    ChatLiveMeta? meta,
    required List<ChatMessage> messages,
  }) {
    final subtle = GoogleFonts.outfit(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: TinderStyle.subtle,
      letterSpacing: 0.15,
      height: 1.2,
    );

    if (_otherIsAiBot == true) {
      return Row(
        children: [
          _PresenceDot(color: const Color(0xFF22C55E)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Online',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF15803D),
                letterSpacing: 0.15,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (meta?.otherTyping == true) {
      return Row(
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent.withValues(alpha: 0.9)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Typing…',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
                letterSpacing: 0.2,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    DateTime? lastOther;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].senderId == widget.otherUid) {
        lastOther = messages[i].createdAt;
        break;
      }
    }

    final now = DateTime.now();
    if (lastOther != null && now.difference(lastOther).inMinutes <= 10) {
      return Row(
        children: [
          _PresenceDot(color: const Color(0xFF22C55E)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Active now',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF15803D),
                letterSpacing: 0.15,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (lastOther != null) {
      return Text(
        _lastSeenPhrase(lastOther),
        style: subtle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (meta?.lastSenderId == currentUid && meta?.lastMessageAt != null) {
      return Text(
        'Waiting for a reply…',
        style: subtle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Text(
      'New chat · say hi',
      style: subtle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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

class _PresenceDot extends StatelessWidget {
  final Color color;

  const _PresenceDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _DateSectionPill extends StatelessWidget {
  final String label;

  const _DateSectionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.35,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
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
    final look = _bubbleLook(theme, isMe);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: look.decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: GoogleFonts.outfit(
                color: look.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.42,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTime(message.createdAt),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: look.timeColor,
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

  _BubbleLook _bubbleLook(ChatViewTheme theme, bool isMe) {
    final r = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMe ? 20 : 5),
      bottomRight: Radius.circular(isMe ? 5 : 20),
    );

    if (isMe) {
      const gStart = Color(0xFFFD297B);
      const gEnd = Color(0xFFFF5864);
      return _BubbleLook(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gStart, gEnd],
          ),
          borderRadius: r,
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5864).withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        textColor: Colors.white,
        timeColor: Colors.white.withValues(alpha: 0.78),
      );
    }

    switch (theme) {
      case ChatViewTheme.light:
        return _BubbleLook(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: r,
            border: Border.all(color: TinderStyle.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          textColor: TinderStyle.ink,
          timeColor: TinderStyle.subtle,
        );
      case ChatViewTheme.midnight:
        return _BubbleLook(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: r,
            border: Border.all(color: const Color(0xFF334155)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          textColor: Colors.white.withValues(alpha: 0.95),
          timeColor: Colors.white.withValues(alpha: 0.55),
        );
      case ChatViewTheme.aurora:
        return _BubbleLook(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: r,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          textColor: TinderStyle.ink,
          timeColor: TinderStyle.subtle,
        );
    }
  }
}

class _BubbleLook {
  final BoxDecoration decoration;
  final Color textColor;
  final Color timeColor;

  const _BubbleLook({
    required this.decoration,
    required this.textColor,
    required this.timeColor,
  });
}

enum ChatViewTheme { aurora, midnight, light }
