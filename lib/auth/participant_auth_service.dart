import '../data/models.dart';

/// Details typed on the login screen.
class LoginDetails {
  const LoginDetails({
    required this.name,
    required this.email,
    required this.mobile,
  });

  final String name;
  final String email;
  final String mobile;
}

/// Who is signed in after an email link (or on app start).
sealed class SignInState {
  const SignInState();
}

class SignedIn extends SignInState {
  const SignedIn(this.person);
  final Person person;
}

/// The link is valid but this device does not know which email it was sent
/// to (e.g. opened on another phone). Ask the user and call
/// [AuthService.completeSignIn] again with the email.
class EmailNeeded extends SignInState {
  const EmailNeeded();
}

class SignInFailed extends SignInState {
  const SignInFailed(this.message);
  final String message;
}

/// A user-facing failure while sending a link.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sign-in as the screens see it. Implemented with Firebase email-link
/// sign-in in [FirebaseAuthService]; tests use a fake.
abstract class AuthService {
  /// Emails a one-tap sign-in link. The name and mobile number are checked
  /// against the registration after the link is opened. Throws [AuthFailure].
  Future<void> sendSignInLink(LoginDetails details);

  /// Whether [link] is an email sign-in link for this app.
  bool isSignInLink(Uri link);

  /// Completes sign-in from a tapped email link.
  Future<SignInState> completeSignIn(Uri link, {String? email});

  /// The signed-in user on app start, or null.
  Future<SignInState?> restore();

  Future<void> signOut();
}

/// Optional testing capability; production email-link authentication stays intact.
abstract interface class InAppVerification {
  bool get testingVerificationEnabled;
  Uri? get testingVerificationLink;
}

/// Temporary testing bypass. The original email verification flow is retained.
abstract interface class AutomaticEmailVerification {
  bool get automaticEmailVerificationEnabled;
  Future<SignInState> continueWithoutVerification(LoginDetails details);
}

/// Bundled demo accounts that continue without email; other registrations
/// sign in with an emailed one-time code.
abstract interface class DemoAccountLookup {
  Future<bool> isDemoAccount(String email);
}

/// Registrations a Super Admin marked as test accounts in the dashboard sign
/// in without an emailed code.
abstract interface class TestAccountLogin {
  /// [SignedIn] for a test account, null when [details] are not one (the
  /// caller then uses email OTP), or [SignInFailed] if sign-in broke.
  Future<SignInState?> signInTestAccount(LoginDetails details);
}

class EmailOtpChallenge {
  const EmailOtpChallenge(this.id);
  final String id;
}

abstract interface class EmailOtpAuthentication {
  bool get emailOtpEnabled;
  Future<EmailOtpChallenge> requestEmailOtp(
    LoginDetails details, {
    bool resend = false,
  });
  Future<SignInState> verifyEmailOtp(
    LoginDetails details,
    EmailOtpChallenge challenge,
    String code,
  );
}
