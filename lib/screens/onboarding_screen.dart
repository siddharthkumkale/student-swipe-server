import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/app_theme.dart';
import '../utils/tinder_style.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardData> _pages = const [
    _OnboardData(
      title: "Find teammates at your uni",
      subtitle:
          "Discover students nearby who share your interests, skills, and campus.",
      asset: 'assets/images/onboarding1.png',
    ),
    _OnboardData(
      title: "Match by skills, not looks",
      subtitle:
          "Swipe on skills, courses, and goals to form focused project teams.",
      asset: 'assets/images/onboarding2.png',
    ),
    _OnboardData(
      title: "Chat, plan, and build",
      subtitle:
          "Once you match, start a conversation and turn ideas into real projects.",
      asset: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onFinish();
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
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onFinish,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final p = _pages[i];
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        key: ValueKey(p.title),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 260,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Image.asset(
                                  p.asset,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Step ${_index + 1} of ${_pages.length}',
                              style: TinderStyle.sectionCaps(
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              p.title,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                height: 1.12,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              p.subtitle,
                              textAlign: TextAlign.center,
                              style: TinderStyle.screenSubtitle(
                                Colors.white.withValues(alpha: 0.76),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                child: Column(
                  children: [
                    _Dots(current: _index, count: _pages.length),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: TinderStyle.ink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: _next,
                        child: Text(
                          _index == _pages.length - 1 ? 'Get Started' : 'Next',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Swipe left/right to explore',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.52),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
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
}

class _OnboardData {
  final String title;
  final String subtitle;
  final String asset;
  const _OnboardData({
    required this.title,
    required this.subtitle,
    required this.asset,
  });
}

class _Dots extends StatelessWidget {
  final int current;
  final int count;

  const _Dots({required this.current, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          height: 8,
          width: active ? 24 : 8,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
    );
  }
}
