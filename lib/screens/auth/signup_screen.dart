import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/tinder_style.dart';
import '../../widgets/auth_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _nameValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Name is required';
    if (value.length < 2) return 'Enter your full name';
    return null;
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

  String? _confirmValidator(String? v) {
    if ((v ?? '').isEmpty) return 'Confirm your password';
    if (v != _password.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1) Create the account
      await AuthService.instance.signUp(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Signup failed";

      if (e.code == 'email-already-in-use') {
        msg = "An account already exists for this email. Try logging in instead, or use Forgot password.";
      } else if (e.code == 'weak-password') {
        msg = "Password is too weak (minimum 6 characters).";
      } else if (e.code == 'invalid-email') {
        msg = "Invalid email address.";
      } else if (e.code == 'network-request-failed') {
        msg = "Network error. Check your internet connection and try again.";
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;

      // Non-FirebaseAuthException. Some Firebase plugins throw internal casting
      // errors even when the user account was actually created. If a user is
      // now signed in, we treat this as a soft success and continue with the
      // verification flow instead of showing a hard failure.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Signup failed. Please try again.")),
        );
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    // 2) Account is created at this point. Try to send verification + sign out,
    // but DO NOT treat failures here as overall signup failures.
    String? emailError;
    try {
      await AuthService.instance.sendVerificationEmail();
    } on FirebaseAuthException catch (e) {
      emailError = e.message ?? 'We could not send a verification email right now.';
    } catch (e) {
      emailError = 'We could not send a verification email right now. ($e)';
    }

    try {
      await AuthService.instance.signOut();
    } catch (_) {
      // Ignore sign-out errors at this stage; the account is already created.
    }

    if (!mounted) {
      setState(() => _loading = false);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: TinderStyle.border),
        ),
        title: Text('Verify your email', style: TinderStyle.cardTitle()),
        content: Text(
          emailError == null
              ? "A verification link has been sent to:\n\n${_email.text.trim()}\n\n"
                "Please check your inbox and verify your email before logging in."
              : "Your account has been created, but we couldn't send the verification email.\n\n"
                "You can try logging in now, or use 'Forgot password' to get an email from Firebase.\n\n"
                "Details: $emailError",
          style: TinderStyle.bodyCard(color: TinderStyle.muted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
              ),
            ),
          )
        ],
      ),
    );

    if (mounted) setState(() => _loading = false);
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
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
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
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const _Header(
                        title: 'Create account',
                        subtitle:
                            'Set up your Student Swipe profile in minutes.',
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
                                controller: _name,
                                hint: 'Full name',
                                prefixIcon: const Icon(Icons.person_outline),
                                validator: _nameValidator,
                              ),
                              const SizedBox(height: 14),
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
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
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
                              const SizedBox(height: 14),
                              AuthTextField(
                                forLightCard: true,
                                controller: _confirm,
                                hint: 'Confirm password',
                                obscureText: _hideConfirm,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _hideConfirm = !_hideConfirm,
                                  ),
                                  icon: Icon(
                                    _hideConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: TinderStyle.muted,
                                  ),
                                ),
                                validator: _confirmValidator,
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _loading ? null : _onSignup,
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
                                        'Create Account',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'By creating an account you agree to our Terms & Privacy Policy.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: TinderStyle.subtle,
                                  height: 1.4,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
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
