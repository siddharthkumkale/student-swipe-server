import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/play_store_config.dart';
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
                    const SizedBox(height: 24),
                    Text(
                      'LEGAL',
                      style: TinderStyle.sectionCaps(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 12),
                    _SettingsTile(
                      icon: Icons.policy_rounded,
                      title: 'Privacy policy',
                      subtitle: PlayStoreConfig.isPrivacyPolicyConfigured
                          ? 'Opens in browser'
                          : 'Required for Play — set URL in app config',
                      onTap: () => _openConfiguredUrl(
                        context,
                        PlayStoreConfig.privacyPolicyUrl,
                        'Set websiteBaseUrl in lib/config/play_store_config.dart to your GitHub Pages root (e.g. https://you.github.io/repo). Google Play requires a privacy policy URL.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.article_outlined,
                      title: 'Terms of use',
                      subtitle: PlayStoreConfig.isTermsConfigured
                          ? 'Opens in browser'
                          : 'Set websiteBaseUrl for docs/terms.html',
                      onTap: () => _openConfiguredUrl(
                        context,
                        PlayStoreConfig.termsOfServiceUrl,
                        'Set websiteBaseUrl in lib/config/play_store_config.dart so Terms (docs/terms.html) can open in the browser.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.person_off_outlined,
                      title: 'Delete account',
                      subtitle: PlayStoreConfig.isAccountDeletionHelpConfigured
                          ? 'Email us or open web instructions'
                          : 'Request removal of your data (Play requirement)',
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                    const SizedBox(height: 10),
                    _SettingsTile(
                      icon: Icons.support_agent_rounded,
                      title: 'Help & support',
                      subtitle: PlayStoreConfig.isSupportConfigured
                          ? 'Opens in browser'
                          : 'Set websiteBaseUrl for docs/support.html',
                      onTap: () => _openConfiguredUrl(
                        context,
                        PlayStoreConfig.supportUrl,
                        'Set websiteBaseUrl in lib/config/play_store_config.dart for the support page (docs/support.html).',
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About',
                      subtitle: 'Version & build info',
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

  void _showDeleteAccountDialog(BuildContext context) {
    final email = PlayStoreConfig.accountDeletionEmail.trim();
    final helpUrl = PlayStoreConfig.accountDeletionInstructionsUrl.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete account',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 18, color: TinderStyle.ink),
        ),
        content: Text(
          email.isEmpty
              ? 'Set accountDeletionEmail in lib/config/play_store_config.dart to a mailbox you monitor. '
                  'Users must be able to request deletion of their account and data.\n\n'
                  'After you add it, this button opens their email app with a pre-filled request.'
              : 'To delete your account and associated data (profile, matches, chats), send an email from '
                  'the address you used to sign up. We will process requests as required by Google Play.\n\n'
                  'Contact: $email${helpUrl.isNotEmpty ? '\n\nYou can also open step-by-step instructions on our website (Web instructions).' : ''}',
          style: GoogleFonts.outfit(color: TinderStyle.muted, height: 1.45, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.outfit(color: TinderStyle.muted, fontWeight: FontWeight.w700)),
          ),
          if (PlayStoreConfig.isAccountDeletionHelpConfigured)
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openConfiguredUrl(
                  context,
                  helpUrl,
                  'Set websiteBaseUrl in lib/config/play_store_config.dart for the delete-account page.',
                );
              },
              child: Text('Web instructions', style: GoogleFonts.outfit(color: AppTheme.accent, fontWeight: FontWeight.w800)),
            ),
          if (email.isNotEmpty)
            FilledButton(
              onPressed: () async {
                final subject = Uri.encodeComponent('Student Swipe — account deletion request');
                final body = Uri.encodeComponent(
                  'Please delete my Student Swipe account and my data. My registered email is:\n\n',
                );
                final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
                try {
                  await launchUrl(uri);
                } catch (_) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('No email app available. Copy the address from the dialog.')),
                    );
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              child: Text('Open email', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Student Swipe',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 20, color: TinderStyle.ink),
        ),
        content: Text(
          'Connect with students through skill-based swiping.\n\n'
          'Version ${info.version} (${info.buildNumber})',
          style: GoogleFonts.outfit(color: TinderStyle.muted, height: 1.45, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('OK', style: GoogleFonts.outfit(color: AppTheme.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

Future<void> _openConfiguredUrl(BuildContext context, String url, String emptyHint) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(emptyHint), duration: const Duration(seconds: 5)),
    );
    return;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid URL in app config.')),
    );
    return;
  }
  if (!await canLaunchUrl(uri)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open this link on this device.')),
      );
    }
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
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
