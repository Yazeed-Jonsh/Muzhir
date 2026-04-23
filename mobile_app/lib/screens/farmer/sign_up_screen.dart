import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:muzhir/l10n/app_localizations.dart';
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authAccountCreated)),
        );
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      final l10n = AppLocalizations.of(context)!;
      final message = switch (e.code) {
        'weak-password' => l10n.authWeakPassword,
        'email-already-in-use' => l10n.authEmailAlreadyInUse,
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
    final l10n = AppLocalizations.of(context)!;
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
      title: l10n.authCreateAccount,
      subtitle: l10n.authCreateAccountSubtitle,
      cardContent: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            muzhirAuthInputLabel(l10n.authFullName),
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
                hintText: l10n.authHintYourName,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.authFullNameRequired;
                return null;
              },
            ),
            const SizedBox(height: 22),
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
                hintText: l10n.authHintPasswordMin,
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
                if (v == null || v.isEmpty) return l10n.authPasswordRequiredSignup;
                if (v.length < 6) {
                  return l10n.authPasswordTooShort;
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
                  TextSpan(text: l10n.authTermsIntro),
                  TextSpan(
                    text: l10n.authTermsOfService,
                    style: termsAccent,
                  ),
                  TextSpan(text: l10n.authTermsAnd),
                  TextSpan(
                    text: l10n.authPrivacyPolicy,
                    style: termsAccent,
                  ),
                  TextSpan(text: l10n.authTermsOutro),
                ],
              ),
            ),
            const SizedBox(height: 30),
            MuzhirAuthPrimaryButton(
              label: l10n.authSignUp,
              loading: _isLoading,
              onPressed: _onSignUp,
            ),
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
                  question: l10n.authAlreadyHaveAccount,
                  action: l10n.authLogIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
