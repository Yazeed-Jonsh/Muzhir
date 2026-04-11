import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/muzhir_auth_page_layout.dart';
import '../../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      final message = switch (e.code) {
        'weak-password' => 'Password is too weak. Use at least 6 characters.',
        'email-already-in-use' => 'An account already exists with this email.',
        _ => e.message ?? e.code,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: scheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: scheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termsStyle = GoogleFonts.lexend(
      fontSize: 11,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: MuzhirColors.mutedGrey,
    );
    final termsAccent = GoogleFonts.lexend(
      fontSize: 11,
      height: 1.45,
      fontWeight: FontWeight.w700,
      color: MuzhirColors.forestGreen,
    );

    return MuzhirAuthPageLayout(
      showBackButton: true,
      title: 'Create Account',
      subtitle:
          'Start protecting your plants with AI-powered disease detection.',
      cardContent: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            muzhirAuthInputLabel('Full Name'),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: MuzhirColors.titleCharcoal,
              ),
              decoration: muzhirAuthInputDecoration(
                context: context,
                prefixIcon: Icons.person_outline_rounded,
                hintText: 'Your name',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your name';
                return null;
              },
            ),
            const SizedBox(height: 22),
            muzhirAuthInputLabel('Email Address'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: MuzhirColors.titleCharcoal,
              ),
              decoration: muzhirAuthInputDecoration(
                context: context,
                prefixIcon: Icons.email_outlined,
                hintText: 'your@email.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 22),
            muzhirAuthInputLabel('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: MuzhirColors.titleCharcoal,
              ),
              decoration: muzhirAuthInputDecoration(
                context: context,
                prefixIcon: Icons.lock_outline_rounded,
                hintText: 'At least 6 characters',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: MuzhirColors.forestGreen,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            Text.rich(
              textAlign: TextAlign.center,
              TextSpan(
                style: termsStyle,
                children: [
                  const TextSpan(
                    text: 'By signing up, you agree to our ',
                  ),
                  TextSpan(
                    text: 'Terms of Service',
                    style: termsAccent,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: termsAccent,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            MuzhirAuthPrimaryButton(
              label: 'Sign Up',
              loading: _isLoading,
              onPressed: _onSignUp,
            ),
            // This controls the gap between the card/button and the footer link
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: MuzhirColors.mutedGrey,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: muzhirAuthFooterLinkRichText(
                  question: 'Already have an account? ',
                  action: 'Log In',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
