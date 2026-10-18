import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_scope.dart';
import 'app/app_session.dart';
import 'app/selfie_store.dart';
import 'app/theme.dart';
import 'auth/firebase_auth_service.dart';
import 'auth/participant_auth_service.dart';
import 'coupons/coupon_service.dart';
import 'coupons/firestore_coupon_service.dart';
import 'data/cone_repository.dart';
import 'data/firestore_repository.dart';
import 'data/models.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/selfie_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Android reads the project settings from android/app/google-services.json.
  await Firebase.initializeApp();
  final repository = FirestoreConeRepository();
  final links = AppLinks();
  runApp(
    ConeApp(
      repository: repository,
      auth: FirebaseAuthService(repository),
      coupons: FirestoreCouponService(),
      selfies: LocalSelfieStore(),
      session: AppSession(),
      initialLink: links.getInitialLink(),
      incomingLinks: links.uriLinkStream,
    ),
  );
}

class ConeApp extends StatefulWidget {
  const ConeApp({
    super.key,
    required this.repository,
    required this.auth,
    required this.coupons,
    required this.selfies,
    required this.session,
    this.initialLink,
    this.incomingLinks,
  });

  final ConeRepository repository;
  final AuthService auth;
  final CouponService coupons;
  final SelfieStore selfies;
  final AppSession session;

  /// The link that launched the app, if any (e.g. a tapped sign-in email).
  final Future<Uri?>? initialLink;

  /// Links received while the app is running.
  final Stream<Uri>? incomingLinks;

  @override
  State<ConeApp> createState() => _ConeAppState();
}

class _ConeAppState extends State<ConeApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSub;
  bool _handlingLink = false;

  @override
  void initState() {
    super.initState();
    _linkSub = widget.incomingLinks?.listen(_handleLink);
    widget.initialLink?.then((uri) {
      if (uri != null) _handleLink(uri);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _handleLink(Uri link) async {
    if (_handlingLink || !widget.auth.isSignInLink(link)) return;
    _handlingLink = true;
    try {
      var state = await widget.auth.completeSignIn(link);
      if (state is EmailNeeded) {
        final email = await _askEmail();
        if (email == null) return;
        state = await widget.auth.completeSignIn(link, email: email);
      }
      switch (state) {
        case SignedIn(:final person):
          await _openHome(person);
        case SignInFailed(:final message):
          _messenger.currentState?.showSnackBar(
            SnackBar(content: Text(message)),
          );
        case EmailNeeded():
          break;
      }
    } finally {
      _handlingLink = false;
    }
  }

  /// Dashboard if a selfie is already stored on this phone, else the selfie.
  Future<void> _openHome(Person person) async {
    final selfie = await widget.selfies.load(person.email);
    widget.session.signIn(person, selfie: selfie);
    _navigator.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => selfie == null
            ? SelfieScreen(person: person)
            : DashboardScreen(person: person),
      ),
      (_) => false,
    );
  }

  Future<String?> _askEmail() async {
    final context = _navigator.currentContext;
    if (context == null) return null;
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _ConfirmEmailDialog(),
    );
    // Let the dialog finish closing before the next screen replaces it.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return (email == null || email.trim().isEmpty) ? null : email;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      repository: widget.repository,
      auth: widget.auth,
      coupons: widget.coupons,
      selfies: widget.selfies,
      session: widget.session,
      // Rebuilds the theme when the signed-in role changes.
      child: ListenableBuilder(
        listenable: widget.session,
        builder: (context, _) => MaterialApp(
          title: 'CONE',
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(role: widget.session.role),
          home: const _StartGate(),
        ),
      ),
    );
  }
}

/// Resumes a signed-in session on launch, otherwise shows the login screen.
class _StartGate extends StatefulWidget {
  const _StartGate();

  @override
  State<_StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<_StartGate> {
  Future<Person?>? _restore;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restore ??= _resume(AppScope.of(context));
  }

  static Future<Person?> _resume(AppScope scope) async {
    final state = await scope.auth.restore();
    if (state is! SignedIn) return null;
    final selfie = await scope.selfies.load(state.person.email);
    scope.session.signIn(state.person, selfie: selfie);
    return state.person;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Person?>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.navy,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.tealBright),
            ),
          );
        }
        final person = snapshot.data;
        return person == null
            ? const LoginScreen()
            : DashboardScreen(person: person);
      },
    );
  }
}

/// Asks which address a sign-in link was sent to (link opened on a device
/// that did not request it). Owns its controller so it outlives the closing
/// animation.
class _ConfirmEmailDialog extends StatefulWidget {
  const _ConfirmEmailDialog();

  @override
  State<_ConfirmEmailDialog> createState() => _ConfirmEmailDialogState();
}

class _ConfirmEmailDialogState extends State<_ConfirmEmailDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your email'),
      content: TextField(
        key: const Key('confirmEmailField'),
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email the link was sent to',
        ),
        onSubmitted: _close,
      ),
      actions: [
        TextButton(onPressed: _close, child: const Text('Cancel')),
        FilledButton(
          key: const Key('confirmEmailContinue'),
          onPressed: () => _close(_controller.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
