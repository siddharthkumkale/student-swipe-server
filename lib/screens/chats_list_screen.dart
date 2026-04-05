import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/chat_preview.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import '../widgets/profile_avatar_image.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(backgroundColor: Colors.transparent, body: Center(child: Text('Not signed in')));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withValues(alpha: 0.12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Messages', style: TinderStyle.screenTitle()),
                          const SizedBox(height: 4),
                          Text(
                            'Chats with your matches',
                            style: TinderStyle.screenSubtitle(Colors.white.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<ChatPreview>>(
                  stream: ChatService.instance.myChatsStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Center(
                          child: Text(
                            'Couldn\'t load chats',
                            textAlign: TextAlign.center,
                            style: TinderStyle.bodyOnDarkMuted(),
                          ),
                        ),
                      );
                    }
                    final list = snapshot.data ?? [];
                    if (list.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [TinderStyle.cardShadow()],
                          ),
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
                          ),
                        ),
                      );
                    }
                    if (list.isEmpty) {
                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 400),
                                  child: Material(
                                    color: Colors.white,
                                    elevation: 8,
                                    shadowColor: Colors.black.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(22),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.accent.withValues(alpha: 0.1),
                                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                                            ),
                                            child: Icon(Icons.chat_bubble_outline_rounded,
                                                size: 36, color: AppTheme.accent.withValues(alpha: 0.9)),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'No conversations yet',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 21,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                              color: TinderStyle.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'When you match, open Notifications and start chatting from there.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.outfit(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              height: 1.45,
                                              color: TinderStyle.muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: list.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'YOUR CHATS',
                              style: TinderStyle.sectionCaps(color: Colors.white.withValues(alpha: 0.5)),
                            ),
                          );
                        }
                        final preview = list[index - 1];
                        return _ChatTile(preview: preview, currentUid: uid);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatPreview preview;
  final String currentUid;

  const _ChatTile({required this.preview, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ProfileService.instance.getProfile(preview.otherUid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final name = profile?.name ?? 'Someone';
        final photoUrl = profile?.photoUrl;
        final unread = preview.isUnread(currentUid);
        final activeRecently = _isActiveRecently(preview.lastMessageAt);

        Widget avatarPlaceholder() => Container(
              color: const Color(0xFFE8EAED),
              alignment: Alignment.center,
              child: Icon(Icons.person_rounded, color: Colors.grey.shade500, size: 28),
            );

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [TinderStyle.cardShadow()],
            ),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: unread
                      ? AppTheme.accent.withValues(alpha: 0.45)
                      : TinderStyle.border,
                  width: unread ? 1.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        otherUid: preview.otherUid,
                        otherName: name,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: unread
                                ? AppTheme.accent.withValues(alpha: 0.35)
                                : const Color(0xFFE5E7EB),
                            width: unread ? 2 : 1,
                          ),
                        ),
                        child: ClipOval(
                          child: profileSnap.connectionState == ConnectionState.waiting
                              ? Container(
                                  color: const Color(0xFFE8EAED),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  ),
                                )
                              : ProfileAvatarImage(
                                  photoUrl: photoUrl,
                                  width: 58,
                                  height: 58,
                                  fit: BoxFit.cover,
                                  placeholder: avatarPlaceholder,
                                  errorWidget: avatarPlaceholder,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                                      letterSpacing: -0.3,
                                      color: TinderStyle.ink,
                                      height: 1.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (preview.lastMessageAt != null) ...[
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      _formatTime(preview.lastMessageAt!),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: TinderStyle.subtle,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (preview.otherTyping) ...[
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Typing…',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (preview.lastMessageText != null) ...[
                              Text(
                                preview.lastMessageText!,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                  color: TinderStyle.muted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else
                              Text(
                                'Say hi 👋',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: TinderStyle.subtle,
                                ),
                              ),
                            if (!preview.otherTyping && activeRecently) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Active recently',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: AppTheme.accent.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (unread)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.day}/${d.month}';
  }

  bool _isActiveRecently(DateTime? d) {
    if (d == null) return false;
    return DateTime.now().difference(d).inMinutes <= 10;
  }
}
