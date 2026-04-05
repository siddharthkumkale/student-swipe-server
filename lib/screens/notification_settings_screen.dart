import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final _prefs = NotificationPreferences.instance;
  bool _matchNotif = true;
  bool _messageNotif = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final matches = await _prefs.matchNotifications;
    final messages = await _prefs.messageNotifications;
    if (mounted) {
      setState(() {
        _matchNotif = matches;
        _messageNotif = messages;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          Text('Notifications', style: TinderStyle.screenTitle()),
                          const SizedBox(height: 4),
                          Text(
                            'Choose what we notify you about',
                            style: TinderStyle.screenSubtitle(Colors.white.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: _loading
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [TinderStyle.cardShadow()],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 3),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Loading preferences…',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: TinderStyle.ink),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        children: [
                          Text(
                            'PUSH ALERTS',
                            style: TinderStyle.sectionCaps(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 12),
                          _buildTile(
                            icon: Icons.favorite_rounded,
                            title: 'New matches',
                            subtitle: 'When you match with someone',
                            value: _matchNotif,
                            onChanged: (v) async {
                              setState(() => _matchNotif = v);
                              await _prefs.setMatchNotifications(v);
                            },
                          ),
                          const SizedBox(height: 10),
                          _buildTile(
                            icon: Icons.chat_bubble_rounded,
                            title: 'New messages',
                            subtitle: 'When someone texts you',
                            value: _messageNotif,
                            onChanged: (v) async {
                              setState(() => _messageNotif = v);
                              await _prefs.setMessageNotifications(v);
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.accent,
            ),
          ],
        ),
      ),
    );
  }
}
