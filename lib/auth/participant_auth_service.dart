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
