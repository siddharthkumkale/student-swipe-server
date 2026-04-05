import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'splash_screen.dart';
import 'onboarding_screen.dart';
import 'auth/auth_gate.dart';

class AppStart extends StatefulWidget {
  const AppStart({super.key});

  @override
  State<AppStart> createState() => _AppStartState();
}

class _AppStartState extends State<AppStart> {
  static const _seenOnboardingKey = 'seen_onboarding_v1';
  int _step = 0;
  bool _hasSeenOnboarding = false;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_seenOnboardingKey) ?? false;
    if (!mounted) return;
    setState(() => _hasSeenOnboarding = seen);
  }

  void _goNext() {
    if (_hasSeenOnboarding) {
      _goAuth();
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
    if (!mounted) return;
    setState(() => _hasSeenOnboarding = true);
    _goAuth();
  }

  void _goAuth() => setState(() => _step = 2);

  @override
  Widget build(BuildContext context) {
    Widget current;
    if (_step == 0) {
      current = SplashScreen(onGetStarted: _goNext);
    } else if (_step == 1) {
      current = OnboardingScreen(onFinish: _finishOnboarding);
    } else {
      current = const AuthGate();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.06, 0.02),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(_step),
        child: current,
      ),
    );
  }
}
