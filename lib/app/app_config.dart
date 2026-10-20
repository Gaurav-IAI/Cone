import 'package:flutter/foundation.dart';

/// Build settings for the mobile app, kept in one place.
///
/// Defaults are embedded so `flutter run` works without flags. Override a
/// value with `--dart-define=NAME=value`, or a whole set with
/// `--dart-define-from-file=config/<name>.json` (see `config/`).
abstract final class AppConfig {
  /// The CONE admin API (separate `cone-admin-dashboard` repository) that
  /// issues and verifies email OTP codes. Debug builds use the development PC
  /// on the local Wi-Fi; release builds must set an HTTPS address.
  static const authApiUrl = String.fromEnvironment(
    'AUTH_API_URL',
    defaultValue: kReleaseMode ? '' : _developmentApiUrl,
  );
  static const _developmentApiUrl = 'http://172.16.9.197:8080';

  /// `production` enforces HTTPS and OTP-only login.
  static const appEnv = String.fromEnvironment('APP_ENV');
  static const isProduction = appEnv == 'production';

  /// OTP for every account, including the six demo fixtures.
  static const emailOtpLogin = bool.fromEnvironment('EMAIL_OTP_LOGIN');

  /// Demo fixtures sign in directly; everyone else uses OTP.
  static const directDemoLogin = bool.fromEnvironment(
    'DIRECT_DEMO_LOGIN',
    defaultValue: true,
  );

  /// Older testing flows, used only when both OTP modes are off.
  static const inAppEmailVerification = bool.fromEnvironment(
    'IN_APP_EMAIL_VERIFICATION',
    defaultValue: true,
  );
  static const autoVerifyEmail = bool.fromEnvironment(
    'AUTO_VERIFY_EMAIL',
    defaultValue: true,
  );
  static const testVerificationApiUrl = String.fromEnvironment(
    'TEST_VERIFICATION_API_URL',
  );

  static const firebaseProjectDomain =
      'conferencemanagement-239a3.firebaseapp.com';
  static const androidPackageName = 'com.usstc.usstc_conferenc';
}
