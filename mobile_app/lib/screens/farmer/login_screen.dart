import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/theme/app_theme.dart';
import 'package:muzhir/widgets/muzhir_auth_page_layout.dart';
import '../../services/auth_service.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in successfully')),
        );
      }
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
    return MuzhirAuthPageLayout(
      title: 'Welcome Back',
      subtitle: 'Sign in to manage your farm with AI-powered insights.',
      cardContent: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                hintText: 'Enter your password',
                subtleHint: true,
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
                if (v == null || v.isEmpty) return 'Enter your password';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your email first'),
                      ),
                    );
                    return;
                  }
                  try {
                    await AuthService().sendPasswordReset(email);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent!'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    final s = Theme.of(context).colorScheme;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                        ),
                        backgroundColor: s.error,
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MuzhirColors.forestGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            MuzhirAuthPrimaryButton(
              label: 'Login',
              loading: _isLoading,
              onPressed: _onLogin,
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const SignUpScreen(),
                    ),
                  );
                },
                child: muzhirAuthFooterLinkRichText(
                  question: "Don't have an account? ",
                  action: 'Sign Up',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
