import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_record.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../widgets/profile_avatar_image.dart';
import 'match_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _ink = Color(0xFF111827);
  int _matchStreamGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: Text('Not signed in')),
      );
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
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.05,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your mutual likes — tap a match to view their profile',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: StreamBuilder<List<MatchRecord>>(
                  key: ValueKey(_matchStreamGeneration),
                  stream: ProfileService.instance.matchesStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  color: AppTheme.accent,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading matches…',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _ErrorCard(
                          message: 'Something went wrong. Check your connection and try again.',
                          onRetry: () => setState(() => _matchStreamGeneration++),
                        ),
                      );
                    }
                    final matches = snapshot.data ?? [];
                    if (matches.isEmpty) {
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
                                  child: const _EmptyMatchesCard(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                      children: [
                        Text(
                          'YOUR MATCHES',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...matches.map((m) => _MatchTile(record: m)),
                      ],
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

class _EmptyMatchesCard extends StatelessWidget {
  const _EmptyMatchesCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.12),
                    AppTheme.accent.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 40,
                color: AppTheme.accent.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'No matches yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'When you and someone both like each other, they’ll appear here. Keep swiping on Discover!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 44, color: Colors.red.shade300),
            const SizedBox(height: 14),
            Text(
              'Couldn’t load matches',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final MatchRecord record;

  const _MatchTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => MatchDetailScreen(match: record),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: record.photoUrl != null && record.photoUrl!.isNotEmpty
                      ? ProfileAvatarImage(
                          photoUrl: record.photoUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          placeholder: _avatarPlaceholder,
                          errorWidget: _avatarPlaceholder,
                        )
                      : _avatarPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_rounded, size: 13, color: AppTheme.accent.withValues(alpha: 0.95)),
                            const SizedBox(width: 5),
                            Text(
                              'NEW MATCH',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.name.isEmpty ? 'Match' : record.name,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded, size: 15, color: const Color(0xFF9CA3AF)),
                          const SizedBox(width: 5),
                          Text(
                            'Matched ${_formatDate(record.matchedAt)}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person_rounded, size: 32, color: Color(0xFF9CA3AF)),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
