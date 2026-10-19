import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cone_repository.dart';
import '../data/models.dart';
import 'identity_matcher.dart';
import 'participant_auth_service.dart';

/// Firebase email-link (passwordless) sign-in for every role.
///
/// Testing generates a link through the Admin API without email delivery.
/// Set IN_APP_EMAIL_VERIFICATION=false to restore Firebase email delivery.
/// The link opens the app through the project's Firebase Hosting domain
/// (`/__/auth/links`, see the intent filter in AndroidManifest.xml). After
/// sign-in, the registration is read from `people/{email}` and the typed name
/// and mobile number must match it.
class FirebaseAuthService
    implements
        AuthService,
        InAppVerification,
        AutomaticEmailVerification,
        EmailOtpAuthentication {
  FirebaseAuthService(this._repository, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  @override
  bool get emailOtpEnabled => const bool.fromEnvironment('EMAIL_OTP_LOGIN');

  Future<Map<String, dynamic>> _otpRequest(
    String action,
    Map<String, dynamic> body,
  ) async {
    const base = String.fromEnvironment('AUTH_API_URL');
    if (base.isEmpty) {
      throw const AuthFailure('Authentication server is not configured.');
    }
    final uri = Uri.parse('$base/api/auth/email-otp/$action');
    if (const String.fromEnvironment('APP_ENV') == 'production' &&
        uri.scheme != 'https') {
      throw const AuthFailure('Secure authentication requires HTTPS.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await (() async {
        final request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
        final response = await request.close();
        final value =
            jsonDecode(await utf8.decoder.bind(response).join())
                as Map<String, dynamic>;
        if (response.statusCode != 200) {
          throw AuthFailure(value['error'] as String? ?? 'Sign-in failed.');
        }
        return value;
      })().timeout(const Duration(seconds: 30));
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Unable to reach authentication. Try again.');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<EmailOtpChallenge> requestEmailOtp(
    LoginDetails details, {
    bool resend = false,
  }) async {
    final data = await _otpRequest(resend ? 'resend' : 'request', {
      'name': details.name,
      'email': details.email,
      'mobile': details.mobile,
      'audience': 'mobile',
    });
    return EmailOtpChallenge(data['challengeId'] as String);
  }

  @override
  Future<SignInState> verifyEmailOtp(
    LoginDetails details,
    EmailOtpChallenge challenge,
    String code,
  ) async {
    try {
      final data = await _otpRequest('verify', {
        'challengeId': challenge.id,
        'code': code,
      });
      await _auth.signInWithCustomToken(data['token'] as String);
      final person = await _repository.person(
        IdentityMatcher.normalizeEmail(details.email),
      );
      if (person == null ||
          ['cancelled', 'suspended'].contains(person.registrationStatus) ||
          !IdentityMatcher.matches(
            typedName: details.name,
            typedEmail: details.email,
            typedMobile: details.mobile,
            recordName: person.fullName,
            recordEmail: person.email,
            recordMobile: person.mobile,
          )) {
        await _auth.signOut();
        return const SignInFailed(
          'Your registration is unavailable. Contact the organizer.',
        );
      }
      return SignedIn(person);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      await _auth.signOut();
      return const SignInFailed(
        'Sign-in could not finish. Request a new code.',
      );
    }
  }

  @override
  bool get testingVerificationEnabled => const bool.fromEnvironment(
    'IN_APP_EMAIL_VERIFICATION',
    defaultValue: true,
  );
  @override
  Uri? testingVerificationLink;
  static const _testingApi = String.fromEnvironment(
    'TEST_VERIFICATION_API_URL',
  );

  Future<Map<String, dynamic>> _testRequest(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    if (_testingApi.isEmpty) {
      throw const AuthFailure(
        'This test app is not connected to its sign-in server. Install a build configured for the testing server.',
      );
    }
    final client = HttpClient();
    try {
      client.connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(Uri.parse('$_testingApi$path'));
      request.headers.contentType = ContentType.json;
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      request.write(jsonEncode(body));
      final response = await request.close();
      final data =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw AuthFailure(
          data['error'] as String? ?? 'Testing verification failed.',
        );
      }
      return data;
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure(
        'Cannot reach the testing verification server. No email was sent.',
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  bool get automaticEmailVerificationEnabled =>
      !emailOtpEnabled &&
      testingVerificationEnabled &&
      const bool.fromEnvironment('AUTO_VERIFY_EMAIL', defaultValue: true);

  @override
  Future<SignInState> continueWithoutVerification(LoginDetails details) async {
    if (!automaticEmailVerificationEnabled) {
      return const SignInFailed('Automatic verification is disabled.');
    }
    final email = IdentityMatcher.normalizeEmail(details.email);
    try {
      final result = await _testRequest('/api/testing/continue', {
        'name': details.name,
        'email': email,
        'mobile': details.mobile,
      });
      await _auth.signInWithCustomToken(result['token'] as String);
      final person = await _repository.person(email);
      if (person == null ||
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
          'The details do not match an existing registration.',
        );
      }
      return SignedIn(person);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      return SignInFailed(_describe(e.code));
    }
  }

  static const _projectDomain = 'conferencemanagement-239a3.firebaseapp.com';
  static const _packageName = 'com.usstc.usstc_conferenc';
  static const _pendingEmail = 'pendingSignInEmail';
  static const _pendingName = 'pendingSignInName';
  static const _pendingMobile = 'pendingSignInMobile';

  final ConeRepository _repository;
  final FirebaseAuth _auth;

  @override
  Future<void> sendSignInLink(LoginDetails details) async {
    final email = IdentityMatcher.normalizeEmail(details.email);
    try {
      testingVerificationLink = null;
      if (testingVerificationEnabled) {
        final result = await _testRequest('/api/testing/email-link', {
          'email': email,
          'name': details.name,
          'mobile': details.mobile,
        });
        testingVerificationLink = Uri.parse(result['link'] as String);
      } else {
        await _auth.sendSignInLinkToEmail(
          email: email,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://$_projectDomain/finishSignIn',
            handleCodeInApp: true,
            androidPackageName: _packageName,
            androidInstallApp: false,
            androidMinimumVersion: '1',
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_describe(e.code));
    }
    // Kept on this device so the link can be completed without retyping.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmail, email);
    await prefs.setString(_pendingName, details.name);
    await prefs.setString(_pendingMobile, details.mobile);
  }

  @override
  bool isSignInLink(Uri link) =>
      !emailOtpEnabled && _auth.isSignInWithEmailLink(link.toString());

  @override
  Future<SignInState> completeSignIn(Uri link, {String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    final address = email != null
        ? IdentityMatcher.normalizeEmail(email)
        : prefs.getString(_pendingEmail);
    if (address == null) return const EmailNeeded();
    final typedName = prefs.getString(_pendingName);
    final typedMobile = prefs.getString(_pendingMobile);

    try {
      await _auth.signInWithEmailLink(
        email: address,
        emailLink: link.toString(),
      );
    } on FirebaseAuthException catch (e) {
      return SignInFailed(_describe(e.code));
    }
    for (final key in [_pendingEmail, _pendingName, _pendingMobile]) {
      await prefs.remove(key);
    }

    final Person? person;
    try {
      person = await _repository.person(address);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      return SignInFailed(_describe(e.code));
    }
    if (person == null) {
      await _auth.signOut();
      return SignInFailed('No registration was found for $address.');
    }
    // Only checked when the details were typed on this device.
    if (typedName != null &&
        typedMobile != null &&
        !IdentityMatcher.matches(
          typedName: typedName,
          typedEmail: address,
          typedMobile: typedMobile,
          recordName: person.fullName,
          recordEmail: person.email,
          recordMobile: person.mobile,
        )) {
      await _auth.signOut();
      return const SignInFailed(
        'The name or mobile number does not match the registration for this '
        'email.',
      );
    }
    if (testingVerificationEnabled) {
      try {
        await _testRequest(
          '/api/testing/email-verified',
          {},
          token: await _auth.currentUser!.getIdToken(true),
        );
        testingVerificationLink = null;
      } on AuthFailure catch (e) {
        await _auth.signOut();
        return SignInFailed(e.message);
      }
    }
    return SignedIn(person);
  }

  @override
  Future<SignInState?> restore() async {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    if (emailOtpEnabled) {
      try {
        final result = await _auth.currentUser!.getIdTokenResult(true);
        final claims = result.claims ?? {};
        final verifiedAt = claims['otp_verified_at'];
        if (claims['login_method'] != 'email_otp' ||
            claims['login_audience'] != 'mobile' ||
            verifiedAt is! num ||
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - verifiedAt >
                86400) {
          await _auth.signOut();
          return null;
        }
      } catch (_) {
        return null;
      }
    }
    try {
      final person = await _repository.person(email);
      if (person != null &&
          (!emailOtpEnabled ||
              ![
                "cancelled",
                "suspended",
              ].contains(person.registrationStatus))) {
        return SignedIn(person);
      }
    } on FirebaseException {
      return null; // offline etc.: show login, keep the Firebase session
    }
    await _auth.signOut();
    return null;
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static String _describe(String code) => switch (code) {
    'invalid-email' => 'That email address is not valid.',
    'invalid-action-code' || 'expired-action-code' =>
      'This sign-in link has expired or was already used. Request a new one.',
    'too-many-requests' =>
      'Too many attempts. Please wait a few minutes and try again.',
    'network-request-failed' ||
    'unavailable' => 'No internet connection. Please try again.',
    'operation-not-allowed' =>
      'Email link sign-in is not enabled for this project yet.',
    'unauthorized-continue-uri' || 'unauthorized-domain' =>
      'The sign-in link domain is not authorised in Firebase.',
    'permission-denied' =>
      'Your registration could not be read. Please contact the organisers.',
    _ => 'Sign-in failed ($code). Please try again.',
  };
}
