import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../auth/participant_auth_service.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'selfie_screen.dart';

/// Shown after a sign-in link has been emailed. Tapping the link in the email
/// reopens the app, and the root link listener completes sign-in.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.details, this.challenge});

  final LoginDetails details;
  final EmailOtpChallenge? challenge;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const _resendDelay = 60;

  final _code = TextEditingController();
  EmailOtpChallenge? _challenge;
  Timer? _timer;
  int _wait = _resendDelay;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _wait = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      final auth = AppScope.of(context).auth;
      if (_challenge != null) {
        _challenge = await (auth as EmailOtpAuthentication).requestEmailOtp(
          widget.details,
          resend: true,
        );
        _code.clear();
      } else {
        await auth.sendSignInLink(widget.details);
      }
      if (!mounted) return;
      setState(
        () => _message = _challenge != null
            ? 'A new code has been sent.'
            : 'A new verification link is ready.',
      );
      _startCountdown();
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify(Uri? link) async {
    if (_challenge != null && !RegExp(r'^\d{6}$').hasMatch(_code.text)) {
      setState(() => _message = 'Enter the six-digit code.');
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    final scope = AppScope.of(context);
    try {
      final result = _challenge != null
          ? await (scope.auth as EmailOtpAuthentication).verifyEmailOtp(
              widget.details,
              _challenge!,
              _code.text,
            )
          : await scope.auth.completeSignIn(link!);
      if (!mounted) return;
      if (result is SignedIn) {
        final selfie = await scope.selfies.load(result.person.email);
        if (!mounted) return;
        scope.session.signIn(result.person, selfie: selfie);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email status: Verified')));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => selfie == null
                ? SelfieScreen(person: result.person)
                : DashboardScreen(person: result.person),
          ),
          (_) => false,
        );
      } else {
        setState(
          () => _message = result is SignInFailed
              ? result.message
              : (_challenge != null
                    ? 'Request a new code.'
                    : 'Request a new link.'),
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static String _mask(String email) {
    final at = email.indexOf('@');
    if (at <= 4) return email;
    final local = email.substring(0, at);
    return '${local.substring(0, 2)}${'•' * (local.length - 4)}'
        '${local.substring(local.length - 2)}${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    final testing =
        auth is InAppVerification &&
        (auth as InAppVerification).testingVerificationEnabled;
    final link = testing
        ? (auth as InAppVerification).testingVerificationLink
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _challenge != null
              ? 'Enter email code'
              : testing
              ? 'Verify Email'
              : 'Check your email',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F6F4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _challenge != null
                  ? 'Enter your sign-in code'
                  : testing
                  ? 'Verify your email in the app'
                  : 'We sent you a sign-in link',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mask(widget.details.email),
              key: const Key('sentTo'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 22),
            if (_challenge != null) ...[
              const Text(
                'We sent a six-digit code to this email. Enter it below to '
                'sign in. It expires in five minutes; check Spam if it has '
                'not arrived.',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('emailOtpField'),
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(labelText: 'Email code'),
                onSubmitted: (_) {
                  if (!_sending) _verify(null);
                },
              ),
              FilledButton(
                key: const Key('verifyEmailOtp'),
                onPressed: _sending ? null : () => _verify(null),
                child: Text(_sending ? 'Verifying...' : 'Verify and continue'),
              ),
            ],
            if (testing && _challenge == null) ...[
              const Text(
                'Testing mode: no email was sent. Tap Verify Email to continue.',
              ),
              const SizedBox(height: 12),
              if (link != null)
                SelectableText(
                  link.toString(),
                  key: const Key('verificationLink'),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('verifyEmail'),
                onPressed: _sending || link == null
                    ? null
                    : () => _verify(link),
                child: Text(_sending ? 'Verifying...' : 'Verify Email'),
              ),
            ],
            if (!testing && _challenge == null)
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Step(
                      n: 1,
                      text:
                          'Open the email from ${appName(context)} on this phone.',
                    ),
                    _Step(n: 2, text: 'Tap the sign-in link.'),
                    _Step(
                      n: 3,
                      text: '${appName(context)} opens and signs you in.',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (!testing && _challenge == null)
              const Text(
                'Not there? Check Spam or Promotions. The link expires after a '
                'short time and works once.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
              ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.navy),
              ),
            ],
            const SizedBox(height: 22),
            OutlinedButton(
              key: const Key('resendLink'),
              onPressed: (_wait > 0 || _sending) ? null : _resend,
              child: Text(
                _challenge != null
                    ? (_wait > 0 ? 'Resend code in ${_wait}s' : 'Resend code')
                    : (_wait > 0 ? 'Resend link in ${_wait}s' : 'Resend link'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Use different details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.navy,
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.navy, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
