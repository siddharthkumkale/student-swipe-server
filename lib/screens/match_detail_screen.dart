import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/match_record.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/report_service.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import '../widgets/profile_avatar_image.dart';
import 'chat_screen.dart';

class MatchDetailScreen extends StatelessWidget {
  final MatchRecord match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: ProfileService.instance.getProfile(match.otherUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: DecoratedBox(
            decoration: AppTheme.backgroundDecoration(),
            child: const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
              ),
            ),
          ),
        );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: DecoratedBox(
              decoration: AppTheme.backgroundDecoration(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Profile not found',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: TinderStyle.ink),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Back', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppTheme.accent)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return _MatchDetailContent(profile: profile);
      },
    );
  }
}

class _MatchDetailContent extends StatelessWidget {
  final UserProfile profile;

  const _MatchDetailContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhoto(),
                      const SizedBox(height: 18),
                      _buildInfo(),
                      const SizedBox(height: 22),
                      _MessageButton(profile: profile),
                      const SizedBox(height: 10),
                      _UnmatchButton(profile: profile),
                      const SizedBox(height: 4),
                      _BlockButton(profile: profile),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white.withValues(alpha: 0.95)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: TinderStyle.screenTitle().copyWith(fontSize: 22),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Match',
                  style: TinderStyle.screenSubtitle(Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          PopupMenuButton<_MatchMenuAction>(
            color: Colors.white,
            icon: Icon(Icons.more_vert_rounded, color: Colors.white.withValues(alpha: 0.95)),
            onSelected: (action) {
              switch (action) {
                case _MatchMenuAction.unmatch:
                  _UnmatchButton(profile: profile).confirmUnmatch(context);
                  break;
                case _MatchMenuAction.block:
                  _BlockButton(profile: profile).confirmBlock(context);
                  break;
                case _MatchMenuAction.report:
                  _ReportDialog.show(context: context, profile: profile);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _MatchMenuAction.unmatch,
                child: Text('Unmatch', style: GoogleFonts.outfit(color: TinderStyle.ink, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: _MatchMenuAction.block,
                child: Text('Block user', style: GoogleFonts.outfit(color: TinderStyle.ink, fontWeight: FontWeight.w600)),
              ),
              PopupMenuItem(
                value: _MatchMenuAction.report,
                child: Text('Report user', style: GoogleFonts.outfit(color: TinderStyle.ink, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
              ? ProfileAvatarImage(
                  photoUrl: profile.photoUrl,
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                  placeholder: _placeholder,
                  errorWidget: _placeholder,
                )
              : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 320,
      color: const Color(0xFFE5E7EB),
      child: const Icon(Icons.person_rounded, size: 96, color: Color(0xFF9CA3AF)),
    );
  }

  Widget _buildInfo() {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABOUT',
              style: TinderStyle.sectionCaps(),
            ),
            const SizedBox(height: 14),
            _Row(icon: Icons.school_outlined, text: '${profile.course} • ${profile.university}'),
            if (profile.year.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Row(icon: Icons.calendar_today_outlined, text: profile.year),
            ],
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                profile.bio,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: const Color(0xFF374151),
                ),
              ),
            ],
            if (profile.skills.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'PASSIONS',
                style: TinderStyle.sectionCaps(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: profile.skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
                    ),
                    child: Text(
                      skill,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: TinderStyle.ink,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: TinderStyle.subtle),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: TinderStyle.ink,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageButton extends StatelessWidget {
  final UserProfile profile;

  const _MessageButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                otherUid: profile.uid,
                otherName: profile.name,
              ),
            ),
          );
        },
        icon: const Icon(Icons.chat_bubble_rounded, size: 22),
        label: Text('Message', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _UnmatchButton extends StatelessWidget {
  final UserProfile profile;

  const _UnmatchButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => confirmUnmatch(context),
        child: Text(
          'Unmatch',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> confirmUnmatch(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Unmatch?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: TinderStyle.ink)),
        content: Text(
          'Unmatch with ${profile.name}? You won\'t see each other in matches.',
          style: GoogleFonts.outfit(color: TinderStyle.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: TinderStyle.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Unmatch', style: GoogleFonts.outfit(color: AppTheme.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ProfileService.instance.removeMatch(uid, profile.uid);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unmatched'), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not unmatch: ${e.toString().replaceFirst(RegExp(r'^\[.*\]\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

class _BlockButton extends StatelessWidget {
  final UserProfile profile;

  const _BlockButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => confirmBlock(context),
        child: Text(
          'Block user',
          style: GoogleFonts.outfit(
            color: Colors.red.shade400,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> confirmBlock(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Block user?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: TinderStyle.ink)),
        content: Text(
          'Block ${profile.name}? They won\'t appear in Discover or your matches.',
          style: GoogleFonts.outfit(color: TinderStyle.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: TinderStyle.muted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Block', style: GoogleFonts.outfit(color: AppTheme.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ProfileService.instance.blockUser(uid, profile.uid);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User blocked'), backgroundColor: AppTheme.accent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not block: ${e.toString().replaceFirst(RegExp(r'^\\[.*\\]\\s*'), '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

enum _MatchMenuAction { unmatch, block, report }

class _ReportDialog extends StatefulWidget {
  final UserProfile profile;

  const _ReportDialog({required this.profile});

  static Future<void> show({
    required BuildContext context,
    required UserProfile profile,
  }) {
    return showDialog(
      context: context,
      builder: (context) => _ReportDialog(profile: profile),
    );
  }

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TinderStyle.border),
      ),
      title: Text('Report user', style: TinderStyle.cardTitle()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us briefly what happened with ${widget.profile.name}.',
            style: TinderStyle.bodyCard(color: TinderStyle.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: TinderStyle.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Optional details...',
              hintStyle: GoogleFonts.outfit(
                fontSize: 15,
                color: TinderStyle.subtle,
              ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: TinderStyle.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: TinderStyle.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.accent, width: 2),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: TinderStyle.muted,
            ),
          ),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                )
              : Text(
                  'Send',
                  style: GoogleFonts.outfit(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await ReportService.instance.submitReport(
        reporterUid: uid,
        reportedUid: widget.profile.uid,
        reason: 'user_report',
        details: _controller.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report sent. Thank you for keeping Student Swipe safe.'),
          backgroundColor: AppTheme.accent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send report: ${e.toString().replaceFirst(RegExp(r'^\\[.*\\]\\s*'), '')}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

