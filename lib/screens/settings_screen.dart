import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import 'auth/login_screen.dart';
import 'notification_settings_screen.dart';
import 'profile_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  final UserProfile? currentProfile;

  const SettingsScreen({super.key, this.currentProfile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
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
                            Text('Settings', style: TinderStyle.screenTitle()),
                            const SizedBox(height: 2),
                            Text(
                              'Account & preferences',
                              style: TinderStyle.screenSubtitle(Colors.white.withValues(alpha: 0.55)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Text(
                      'GENERAL',
                      style: TinderStyle.sectionCaps(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.person_rounded,
                      title: 'Edit profile',
                      subtitle: 'Photos, bio, study & skills',
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ProfileSetupScreen(initialProfile: currentProfile),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      subtitle: 'Matches & messages',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    const _ThemeToggleTile(),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Student Swipe v1.0',
                      onTap: () => _showAboutDialog(context),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () => _signOut(context),
                        icon: Icon(Icons.logout_rounded, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                        label: Text(
                          'Log out',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
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

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Student Swipe', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20, color: TinderStyle.ink)),
        content: Text(
          'Connect with students through skill-based swiping.\n\nVersion 1.0.0',
          style: GoogleFonts.outfit(color: TinderStyle.muted, height: 1.45, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.outfit(color: AppTheme.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, size: 22, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TinderStyle.cardTitle()),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TinderStyle.cardSubtitle()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatefulWidget {
  const _ThemeToggleTile();

  @override
  State<_ThemeToggleTile> createState() => _ThemeToggleTileState();
}

class _ThemeToggleTileState extends State<_ThemeToggleTile> {
  @override
  Widget build(BuildContext context) {
    final mode = ThemeService.instance.notifier.value;
    final isDark = mode != ThemeMode.light;

    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await ThemeService.instance.toggleDarkLight();
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.brightness_6_rounded, size: 22, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Appearance', style: TinderStyle.cardTitle()),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Dark mode' : 'Light mode',
                      style: TinderStyle.cardSubtitle(),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                onChanged: (_) async {
                  await ThemeService.instance.toggleDarkLight();
                  setState(() {});
                },
                activeColor: AppTheme.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
