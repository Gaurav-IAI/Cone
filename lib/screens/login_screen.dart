import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../auth/identity_matcher.dart';
import '../auth/participant_auth_service.dart';
import '../widgets/common.dart';
import 'check_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final auth = AppScope.of(context).auth;
    final details = LoginDetails(
      name: _name.text.trim(),
      email: IdentityMatcher.normalizeEmail(_email.text),
      mobile: _mobile.text.trim(),
    );
    setState(() => _submitting = true);
    try {
      await auth.sendSignInLink(details);
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CheckEmailScreen(details: details),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildForm());
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const _Header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    const Text(
                      'Participant sign-in',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Use the name, email and mobile number you registered '
                      'with.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      key: const Key('nameField'),
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        hintText: 'As given at registration',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('emailField'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your email address';
                        }
                        return IdentityMatcher.isValidEmail(v)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      key: const Key('mobileField'),
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '10-digit mobile number',
                        prefixIcon: Icon(Icons.phone_iphone),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter your mobile number';
                        }
                        return IdentityMatcher.normalizeMobile(v) == null
                            ? 'Enter a valid 10-digit mobile number'
                            : null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      NoticeBanner(
                        key: const Key('loginError'),
                        tone: NoticeTone.warning,
                        icon: Icons.person_search_outlined,
                        message: _error!,
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('continueButton'),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We will email you a one-tap sign-in link. For '
                      'participants, speakers, guests, organisers and '
                      'volunteers already registered — new registrations are '
                      'not taken in this app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
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

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 26),
          child: Column(
            children: [
              const ConeLogo(size: 176),
              const SizedBox(height: 4),
              const Text(
                'CONE · $coneFullName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.tealBright,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                conferenceName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
