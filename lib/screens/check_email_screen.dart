import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../auth/participant_auth_service.dart';
import '../widgets/common.dart';

/// Shown after a sign-in link has been emailed. Tapping the link in the email
/// reopens the app, and the root link listener completes sign-in.
class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key, required this.details});

  final LoginDetails details;

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  static const _resendDelay = 60;

  Timer? _timer;
  int _wait = _resendDelay;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
      await AppScope.of(context).auth.sendSignInLink(widget.details);
      if (!mounted) return;
      setState(() => _message = 'A new link is on its way.');
      _startCountdown();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Check your email')),
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
            const Text(
              'We sent you a sign-in link',
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
            const SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Step(n: 1, text: 'Open the email from CONE on this phone.'),
                  _Step(n: 2, text: 'Tap the sign-in link.'),
                  _Step(n: 3, text: 'CONE opens and signs you in.'),
                ],
              ),
            ),
            const SizedBox(height: 14),
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
                _wait > 0 ? 'Resend link in ${_wait}s' : 'Resend link',
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
