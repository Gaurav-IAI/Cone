import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/cone_repository.dart';
import '../data/models.dart';
import 'identity_matcher.dart';
import 'participant_auth_service.dart';

/// Firebase email-link (passwordless) sign-in for every role.
///
/// Firebase sends the email and checks the link; this app never sees a code.
/// The link opens the app through the project's Firebase Hosting domain
/// (`/__/auth/links`, see the intent filter in AndroidManifest.xml). After
/// sign-in, the registration is read from `people/{email}` and the typed name
/// and mobile number must match it.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._repository, {FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

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
  bool isSignInLink(Uri link) => _auth.isSignInWithEmailLink(link.toString());

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
    return SignedIn(person);
  }

  @override
  Future<SignInState?> restore() async {
    final email = _auth.currentUser?.email;
    if (email == null) return null;
    try {
      final person = await _repository.person(email);
      if (person != null) return SignedIn(person);
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
