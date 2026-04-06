import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shown on cold start. Guests see “Get started”; signed-in users get a short
/// branded animation then [onContinueSignedIn] runs automatically.
class SplashScreen extends StatefulWidget {
  /// True while Firebase is still restoring the session (first stream tick).
  final bool resolvingAuth;

  /// True when a user session is active.
  final bool signedIn;

  final VoidCallback onContinueAsGuest;
  final VoidCallback onContinueSignedIn;

  const SplashScreen({
    super.key,
    this.resolvingAuth = false,
    required this.signedIn,
    required this.onContinueAsGuest,
    required this.onContinueSignedIn,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _autoAdvanceSignedIn = Duration(milliseconds: 2600);

  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final AnimationController _shimmer;
  /// Continuous motion: orbit sparkles, float, background drift.
  late final AnimationController _motion;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 14000),
    )..repeat();

    _entrance.forward();
    _scheduleAutoAdvance();
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    if (widget.signedIn && !widget.resolvingAuth) {
      _autoTimer = Timer(_autoAdvanceSignedIn, () {
        if (mounted) widget.onContinueSignedIn();
      });
    }
  }

  @override
  void didUpdateWidget(SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signedIn != widget.signedIn || oldWidget.resolvingAuth != widget.resolvingAuth) {
      _scheduleAutoAdvance();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _entrance.dispose();
    _pulse.dispose();
    _shimmer.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showGuestCta = !widget.resolvingAuth && !widget.signedIn;
    final showWelcomeBack = !widget.resolvingAuth && widget.signedIn;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _motion,
            builder: (context, child) {
              final t = _motion.value * 2 * math.pi;
              final scale = 1.0 + 0.035 * math.sin(t * 0.35);
              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: Image.asset(
              'assets/images/splash_hero.png',
              fit: BoxFit.cover,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x33000000),
                  Color(0xCC000000),
                ],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_shimmer, _motion]),
            builder: (context, child) {
              final s = _shimmer.value;
              final m = _motion.value;
              return IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(
                        0.2 * math.sin(m * 2 * math.pi * 0.7),
                        -0.42 + 0.18 * math.cos(m * 2 * math.pi * 0.5),
                      ),
                      radius: 1.05,
                      colors: [
                        Color.lerp(
                          const Color(0x40FF5864),
                          const Color(0x28FD297B),
                          (math.sin(s * 2 * math.pi) * 0.5 + 0.5),
                        )!,
                        const Color(0x14FF5864),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _motion,
                              builder: (context, _) {
                                return CustomPaint(
                                  painter: _GlowOrbitPainter(phase: _motion.value),
                                );
                              },
                            ),
                          ),
                          AnimatedBuilder(
                            animation: Listenable.merge([_entrance, _pulse, _motion]),
                            builder: (context, child) {
                              final enter = CurvedAnimation(
                                parent: _entrance,
                                curve: Curves.easeOutCubic,
                              ).value;
                              final breathe = Curves.easeInOut.transform(_pulse.value);
                              final mt = _motion.value * 2 * math.pi;
                              final logoScale = (0.88 + 0.12 * enter) * (1.0 + 0.055 * breathe);
                              final swayX = 12 * math.sin(mt * 0.65) * enter;
                              final bobY = 14 * math.sin(mt * 0.48 + 0.9) * enter;
                              final wobble = 0.045 * math.sin(mt * 0.9) * enter;
                              return Opacity(
                                opacity: enter,
                                child: Transform.translate(
                                  offset: Offset(swayX, 28 * (1 - enter) + bobY),
                                  child: Transform.rotate(
                                    angle: wobble,
                                    child: Transform.scale(
                                      scale: logoScale,
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: _LogoGlassCard(
                              shimmer: _shimmer,
                              motion: _motion,
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: 92,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: Listenable.merge([_entrance, _motion]),
                      builder: (context, child) {
                        final enter = CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
                        ).value;
                        final drift = 4 * math.sin(_motion.value * 2 * math.pi * 0.55) * enter;
                        return Transform.translate(
                          offset: Offset(drift, 0),
                          child: Opacity(
                            opacity: enter,
                            child: child,
                          ),
                        );
                      },
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.12),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: _entrance, curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic))),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFF7C0),
                                Color(0xFFFFEDD5),
                                Color(0xFFF97316),
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'Student Swipe',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.05,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showWelcomeBack) ...[
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
                        ),
                        child: Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.72),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                    if (widget.resolvingAuth) ...[
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    if (showGuestCta) ...[
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _entrance,
                          curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF111827),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: widget.onContinueAsGuest,
                            child: Text(
                              'Get started',
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Twinkling dots on a soft orbit around the logo.
class _GlowOrbitPainter extends CustomPainter {
  _GlowOrbitPainter({required this.phase});

  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Slightly larger radius so sparkles sit farther from the logo art (avoids a solid “ring” look).
    final baseR = math.min(size.width, size.height) * 0.48;
    const n = 9;

    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi + phase * 2 * math.pi * 1.35;
      final ripple = 0.92 + 0.1 * math.sin(phase * 2 * math.pi * 2 + i * 0.7);
      final pos = center + Offset(math.cos(a), math.sin(a)) * baseR * ripple;
      final twinkle = 0.32 + 0.48 * (0.5 + 0.5 * math.sin(phase * 10 * math.pi + i * 1.9));
      final t = i / (n - 1);
      // Warm tints only — pure white + heavy blur on a dark blue backdrop often reads as a cyan/blue ring.
      final dotPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
              const Color(0xCCFFD6CC),
              const Color(0xD9FF9EAA),
              t * 0.85,
            )!
            .withValues(alpha: twinkle * 0.34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.55 + (i % 4) * 0.2);
      final radius = 1.8 + (i % 4) * 0.55 + 0.4 * twinkle;
      canvas.drawCircle(pos, radius, dotPaint);
    }

    // Second inner ring, counter-rotating
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * 2 * math.pi - phase * 2 * math.pi * 0.9;
      final pos = center + Offset(math.cos(a), math.sin(a)) * baseR * 0.62;
      final twinkle = 0.4 + 0.35 * math.sin(phase * 12 * math.pi + i * 2.1);
      final p = Paint()
        ..color = const Color(0xFFFFE0D5).withValues(alpha: twinkle * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
      canvas.drawCircle(pos, 2.2, p);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowOrbitPainter oldDelegate) => oldDelegate.phase != phase;
}

class _LogoGlassCard extends StatelessWidget {
  final AnimationController shimmer;
  final AnimationController motion;
  final Widget child;

  const _LogoGlassCard({
    required this.shimmer,
    required this.motion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shimmer, motion]),
      builder: (context, _) {
        final sweep = shimmer.value;
        final m = motion.value * 2 * math.pi;
        final glossShift = 0.5 + 0.5 * math.sin(m * 0.8);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8 + glossShift * 0.5, -1),
              end: Alignment(0.8 - glossShift * 0.3, 1),
              colors: [
                Colors.white.withValues(alpha: 0.26),
                Colors.white.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: Color.lerp(
                const Color(0x99FFF0E8),
                const Color(0xB3FFB4A8),
                (sweep * 2 % 1.0),
              )!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
