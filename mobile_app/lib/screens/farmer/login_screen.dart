import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/l10n/app_localizations.dart';
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authSignedInSuccessfully)),
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
    final l10n = AppLocalizations.of(context)!;

    return MuzhirAuthPageLayout(
      title: l10n.authWelcomeBack,
      subtitle: l10n.authSignInSubtitle,
      cardContent: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            muzhirAuthInputLabel(l10n.authEmailAddress),
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
                hintText: l10n.authHintEmail,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.authEmailRequired;
                if (!v.contains('@')) return l10n.authEmailInvalid;
                return null;
              },
            ),
            const SizedBox(height: 22),
            muzhirAuthInputLabel(l10n.authPassword),
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
                hintText: l10n.authHintPassword,
                subtleHint: true,
                suffixIcon: IconButton(
                  tooltip:
                      _obscurePassword ? l10n.authShowPassword : l10n.authHidePassword,
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
                if (v == null || v.isEmpty) return l10n.authPasswordRequired;
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
                      SnackBar(content: Text(l10n.authEnterEmailFirst)),
                    );
                    return;
                  }
                  try {
                    await AuthService().sendPasswordReset(email);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.authPasswordResetSent)),
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
                  l10n.authForgotPassword,
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
              label: l10n.authLogin,
              loading: _isLoading,
              onPressed: _onLogin,
            ),
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
                  question: l10n.authDontHaveAccount,
                  action: l10n.authSignUp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
