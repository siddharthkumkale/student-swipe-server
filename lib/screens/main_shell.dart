import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'swipe_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const _tabs = [
    _TabData(
      label: 'Discover',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
    ),
    _TabData(
      label: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_active_rounded,
    ),
    _TabData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(0.04, 0.02),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnimation,
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(_currentIndex),
          width: double.infinity,
          height: double.infinity,
          decoration: AppTheme.backgroundDecoration(),
          child: IndexedStack(
            index: _currentIndex,
            children: const [
              SwipeScreen(),
              NotificationsScreen(),
              ProfileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.card.withValues(alpha: 0.97),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = _currentIndex == i;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _NavItem(
                      label: tab.label,
                      icon: tab.icon,
                      selectedIcon: tab.selectedIcon,
                      selected: selected,
                      onTap: () => setState(() => _currentIndex = i),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabData {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _TabData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent;
    final displayIcon = selected ? selectedIcon : icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: accent.withValues(alpha: 0.15),
        highlightColor: accent.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: 0.32),
                      accent.withValues(alpha: 0.14),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.14),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                displayIcon,
                size: 26,
                color: selected ? accent : Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: selected ? 0.15 : 0,
                  color: selected ? accent : TinderStyle.subtle.withValues(alpha: 0.85),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
