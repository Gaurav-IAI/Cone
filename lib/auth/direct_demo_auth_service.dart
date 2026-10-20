import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../data/cone_repository.dart';
import 'firebase_auth_service.dart';
import 'identity_matcher.dart';
import 'participant_auth_service.dart';

/// Direct Firebase authentication for the six fictional testing accounts only;
/// they continue without email. Every other registration signs in with a
/// one-time code emailed to its registered address (see [FirebaseAuthService]).
class DirectDemoAuthService
    implements
        AuthService,
        AutomaticEmailVerification,
        EmailOtpAuthentication,
        DemoAccountLookup {
  DirectDemoAuthService(this._repository, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final ConeRepository _repository;
  final FirebaseAuth _auth;
  late final _otp = FirebaseAuthService(_repository, auth: _auth);
  Map<String, dynamic>? _config;

  Future<Map<String, dynamic>> _demoConfig() async => _config ??=
      jsonDecode(await rootBundle.loadString('assets/testing/demo_login.json'))
          as Map<String, dynamic>;

  @override
  Future<bool> isDemoAccount(String email) async {
    try {
      final config = await _demoConfig();
      final normalized = IdentityMatcher.normalizeEmail(email);
      return config['isDemo'] == true &&
          (config['accounts'] as List).any(
            (a) => (a as Map<String, dynamic>)['email'] == normalized,
          );
    } catch (_) {
      return false;
    }
  }

  @override
  bool get emailOtpEnabled => true;

  @override
  Future<EmailOtpChallenge> requestEmailOtp(
    LoginDetails details, {
    bool resend = false,
  }) => _otp.requestEmailOtp(details, resend: resend);

  @override
  Future<SignInState> verifyEmailOtp(
    LoginDetails details,
    EmailOtpChallenge challenge,
    String code,
  ) => _otp.verifyEmailOtp(details, challenge, code);

  @override
  bool get automaticEmailVerificationEnabled => true;

  @override
  Future<SignInState> continueWithoutVerification(LoginDetails details) async {
    final email = IdentityMatcher.normalizeEmail(details.email);
    try {
      final Map<String, dynamic> config;
      try {
        config = await _demoConfig();
      } catch (_) {
        return const SignInFailed(
          'Demo login is not configured in this build. Please install the updated testing APK.',
        );
      }
      Map<String, dynamic>? account;
      if (config['isDemo'] == true) {
        for (final value in config['accounts'] as List) {
          final candidate = value as Map<String, dynamic>;
          if (candidate['email'] == email) account = candidate;
        }
      }
      if (account == null ||
          !IdentityMatcher.matches(
            typedName: details.name,
            typedEmail: email,
            typedMobile: details.mobile,
            recordName: account['name'] as String,
            recordEmail: email,
            recordMobile: account['mobile'] as String,
          )) {
        return const SignInFailed(
          'The name, email or mobile number does not match a test registration.',
        );
      }
      // Demo credentials authenticate directly with Firebase; all displayed data
      // and role permissions still come from the live, protected database.
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: account['password'] as String,
      );
      final person = await _repository.person(email);
      if (credential.user?.uid != account['uid'] ||
          person == null ||
          person.role.name != account['role'] ||
          !IdentityMatcher.matches(
            typedName: details.name,
            typedEmail: email,
            typedMobile: details.mobile,
            recordName: person.fullName,
            recordEmail: person.email,
            recordMobile: person.mobile,
          )) {
        await _auth.signOut();
        return const SignInFailed(
          'The details do not match the database registration.',
        );
      }
      return SignedIn(person);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      return SignInFailed(switch (e.code) {
        'network-request-failed' ||
        'unavailable' => 'Check your internet connection and try again.',
        'invalid-credential' || 'wrong-password' =>
          'This testing APK needs updated demo login credentials.',
        'user-disabled' => 'This account is disabled.',
        _ => 'Could not sign in (${e.code}). Please try again.',
      });
    }
  }

  // Original verification remains in FirebaseAuthService for restoration.
  // Direct testing login deliberately does not allow any email delivery path.
  @override
  Future<void> sendSignInLink(LoginDetails details) async =>
      throw const AuthFailure('Email verification is disabled for testing.');
  @override
  bool isSignInLink(Uri link) => false;
  @override
  Future<SignInState> completeSignIn(Uri link, {String? email}) async =>
      const SignInFailed('Email verification is disabled for testing.');
  @override
  Future<SignInState?> restore() =>
      FirebaseAuthService(_repository, auth: _auth).restore();
  @override
  Future<void> signOut() => _auth.signOut();
}
