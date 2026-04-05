import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/tinder_style.dart';
import '../../widgets/auth_text_field.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
    if (!ok) return 'Enter a valid email';
    return null;
  }

  String? _passwordValidator(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters';
    return null;
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      await AuthService.instance.reloadUser();
      final user = AuthService.instance.currentUser;

      if (user != null && !user.emailVerified) {
        await AuthService.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please verify your email first. Check your inbox before logging in.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';

      if (e.code == 'invalid-email') {
        msg = 'Invalid email address';
      } else if (e.code == 'invalid-credential') {
        msg = 'Incorrect email or password';
      } else if (e.code == 'user-not-found') {
        msg = 'No user found for this email';
      } else if (e.code == 'wrong-password') {
        msg = 'Wrong password';
      } else if (e.code == 'network-request-failed') {
        msg = 'Network error. Check your internet.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }

    try {
      await AuthService.instance.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } on FirebaseAuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send reset email')),
      );
    }
  }

  Future<void> _onGoogleLogin() async {
    setState(() => _loading = true);

    try {
      final result = await AuthService.instance.signInWithGoogle();

      if (result == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in cancelled')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google sign-in successful')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Google sign-in failed';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Header(
                            title: 'Welcome back',
                            subtitle:
                                'Log in to continue swiping & collaborating.',
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: TinderStyle.border),
                              boxShadow: [TinderStyle.cardShadow()],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AuthTextField(
                                    forLightCard: true,
                                    controller: _email,
                                    hint: 'University email',
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon:
                                        const Icon(Icons.email_outlined),
                                    validator: _emailValidator,
                                  ),
                                  const SizedBox(height: 14),
                                  AuthTextField(
                                    forLightCard: true,
                                    controller: _password,
                                    hint: 'Password',
                                    obscureText: _hidePassword,
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () => setState(
                                        () =>
                                            _hidePassword = !_hidePassword,
                                      ),
                                      icon: Icon(
                                        _hidePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: TinderStyle.muted,
                                      ),
                                    ),
                                    validator: _passwordValidator,
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPassword,
                                      child: Text(
                                        'Forgot password?',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: _loading ? null : _onLogin,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.accent,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Log In',
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 18),
                                  const _DividerText(text: 'or'),
                                  const SizedBox(height: 18),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(54),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: const BorderSide(color: TinderStyle.border),
                                      foregroundColor: TinderStyle.ink,
                                    ),
                                    onPressed:
                                        _loading ? null : _onGoogleLogin,
                                    icon: Icon(Icons.g_mobiledata,
                                        size: 28, color: TinderStyle.ink.withValues(alpha: 0.85)),
                                    label: Text(
                                      'Continue with Google',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
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
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TinderStyle.bodyOnDarkMuted(alpha: 0.85),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Sign Up',
                            style: GoogleFonts.outfit(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
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
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: TinderStyle.screenTitle()),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TinderStyle.screenSubtitle(Colors.white.withValues(alpha: 0.72)),
        ),
      ],
    );
  }
}

class _DividerText extends StatelessWidget {
  final String text;
  const _DividerText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
            child: Divider(color: Colors.white.withValues(alpha: 0.15), thickness: 1)),
      ],
    );
  }
}
