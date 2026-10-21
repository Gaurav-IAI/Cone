import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../auth/identity_matcher.dart';
import '../auth/participant_auth_service.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'check_email_screen.dart';
import 'dashboard_screen.dart';
import 'selfie_screen.dart';

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
      // Accounts marked "Test account" in the dashboard skip the emailed code.
      if (auth is TestAccountLogin) {
        final result = await (auth as TestAccountLogin).signInTestAccount(
          details,
        );
        if (!mounted) return;
        if (result is SignInFailed) throw AuthFailure(result.message);
        if (result is SignedIn) return await _openHome(result.person);
      }
      // The six bundled demo accounts continue without email; everyone else
      // receives a one-time code at their registered email address.
      final demo =
          auth is DemoAccountLookup &&
          await (auth as DemoAccountLookup).isDemoAccount(details.email);
      if (!demo &&
          auth is EmailOtpAuthentication &&
          (auth as EmailOtpAuthentication).emailOtpEnabled) {
        final challenge = await (auth as EmailOtpAuthentication)
            .requestEmailOtp(details);
        if (!mounted) return;
        setState(() => _submitting = false);
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                CheckEmailScreen(details: details, challenge: challenge),
          ),
        );
        return;
      }
      if (auth is AutomaticEmailVerification &&
          (auth as AutomaticEmailVerification)
              .automaticEmailVerificationEnabled) {
        final result = await (auth as AutomaticEmailVerification)
            .continueWithoutVerification(details);
        if (!mounted) return;
        if (result is! SignedIn) {
          throw AuthFailure(
            result is SignInFailed ? result.message : 'Sign-in failed.',
          );
        }
        return await _openHome(result.person);
      }
      // Original manual email verification is temporarily bypassed above.
      // Set AUTO_VERIFY_EMAIL=false to restore it.
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

  /// The selfie step, or the dashboard if a selfie is already on this phone.
  Future<void> _openHome(Person person) async {
    final scope = AppScope.of(context);
    final selfie = await scope.selfies.load(person.email);
    if (!mounted) return;
    scope.session.signIn(person, selfie: selfie);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => selfie == null
            ? SelfieScreen(person: person)
            : DashboardScreen(person: person),
      ),
      (_) => false,
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
                      'Conference sign-in',
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
                    Text(
                      AppScope.of(context).auth is DemoAccountLookup
                          ? 'We will email a one-time code to your registered email address.'
                          : AppScope.of(context).auth
                                    is EmailOtpAuthentication &&
                                (AppScope.of(context).auth
                                        as EmailOtpAuthentication)
                                    .emailOtpEnabled
                          ? 'We will email a one-time code to your registered email address. Verify it to sign in.'
                          : AppScope.of(context).auth is InAppVerification &&
                                (AppScope.of(context).auth as InAppVerification)
                                    .testingVerificationEnabled
                          ? 'Testing mode: Continue signs you in automatically. No email will be sent. Use an existing registration.'
                          : 'We will email you a one-tap sign-in link. For '
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
              Text(
                '${appName(context)} \u00b7 $coneFullName',
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
