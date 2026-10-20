import 'package:usstc_conference/app/branding.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/app/app_session.dart';
import 'package:usstc_conference/app/roles.dart';
import 'package:usstc_conference/app/selfie_store.dart';
import 'package:usstc_conference/data/models.dart';
import 'package:usstc_conference/main.dart';
import 'package:usstc_conference/screens/check_email_screen.dart';
import 'package:usstc_conference/screens/coupon_check_screen.dart';
import 'package:usstc_conference/screens/dashboard_screen.dart';
import 'package:usstc_conference/screens/login_screen.dart';
import 'package:usstc_conference/screens/meal_desk_screen.dart';
import 'package:usstc_conference/screens/people_screen.dart';
import 'package:usstc_conference/screens/qr_pass_screen.dart';
import 'package:usstc_conference/screens/selfie_screen.dart';

import 'fakes.dart';
import 'package:usstc_conference/auth/identity_matcher.dart';
import 'package:usstc_conference/auth/participant_auth_service.dart';

class BrandedRepository extends FakeRepository implements BrandingSource {
  final changes = StreamController<AppBranding>.broadcast();
  @override
  Stream<AppBranding> watchBranding() => changes.stream;
}

class Harness {
  Harness(
    this.repo,
    this.session,
    this.auth,
    this.coupons,
    this.selfies,
    this.links,
  );

  final FakeRepository repo;
  final AppSession session;
  final FakeAuthService auth;
  final FakeCouponService coupons;
  final MemorySelfieStore selfies;
  final StreamController<Uri> links;

  /// Simulates tapping the emailed sign-in link.
  Future<void> tapEmailLink(WidgetTester tester) async {
    links.add(FakeAuthService.sampleLink);
    await tester.pumpAndSettle();
  }
}

class TestingAuth extends FakeAuthService implements InAppVerification {
  TestingAuth(super.repository);
  @override
  bool get testingVerificationEnabled => true;
  @override
  Uri? get testingVerificationLink => FakeAuthService.sampleLink;
}

class AutomaticTestingAuth extends TestingAuth
    implements AutomaticEmailVerification {
  AutomaticTestingAuth(super.repository);
  @override
  bool get automaticEmailVerificationEnabled => true;
  @override
  Future<SignInState> continueWithoutVerification(LoginDetails details) async {
    final person = await repository.person(details.email);
    if (person == null ||
        !IdentityMatcher.matches(
          typedName: details.name,
          typedEmail: details.email,
          typedMobile: details.mobile,
          recordName: person.fullName,
          recordEmail: person.email,
          recordMobile: person.mobile,
        )) {
      return const SignInFailed(
        'The details do not match an existing registration.',
      );
    }
    return SignedIn(person);
  }
}

class OtpTestingAuth extends FakeAuthService implements EmailOtpAuthentication {
  OtpTestingAuth(super.repository);
  int requests = 0;
  @override
  bool get emailOtpEnabled => true;
  @override
  Future<EmailOtpChallenge> requestEmailOtp(
    LoginDetails details, {
    bool resend = false,
  }) async {
    // Like the API: details are checked against the registration before a
    // code is issued.
    final person = await repository.person(details.email);
    if (person == null ||
        !IdentityMatcher.matches(
          typedName: details.name,
          typedEmail: details.email,
          typedMobile: details.mobile,
          recordName: person.fullName,
          recordEmail: person.email,
          recordMobile: person.mobile,
        )) {
      throw const AuthFailure('User data not found in system.');
    }
    requests++;
    return EmailOtpChallenge('challenge-$requests');
  }

  @override
  Future<SignInState> verifyEmailOtp(
    LoginDetails details,
    EmailOtpChallenge challenge,
    String code,
  ) async {
    if (code != '123456') throw const AuthFailure('Invalid or expired code.');
    return SignedIn((await repository.person(details.email))!);
  }
}

/// Mirrors the testing APK: bundled demo accounts continue without email,
/// every other registration signs in with an emailed code.
class MixedTestingAuth extends AutomaticTestingAuth
    implements EmailOtpAuthentication, DemoAccountLookup {
  MixedTestingAuth(super.repository, this.demoEmails);
  final Set<String> demoEmails;
  int requests = 0;
  @override
  Future<bool> isDemoAccount(String email) async => demoEmails.contains(email);
  @override
  bool get emailOtpEnabled => true;
  @override
  Future<EmailOtpChallenge> requestEmailOtp(
    LoginDetails details, {
    bool resend = false,
  }) async {
    requests++;
    return EmailOtpChallenge('challenge-$requests');
  }

  @override
  Future<SignInState> verifyEmailOtp(
    LoginDetails details,
    EmailOtpChallenge challenge,
    String code,
  ) async {
    if (code != '123456') throw const AuthFailure('Invalid or expired code.');
    return SignedIn((await repository.person(details.email))!);
  }
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  bool testing = false,
  bool automatic = false,
  Set<String>? demoEmails,
  bool otpLogin = false,
  FakeRepository? repository,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final repo = repository ?? FakeRepository();
  final session = AppSession();
  final auth = otpLogin
      ? OtpTestingAuth(repo)
      : demoEmails != null
      ? MixedTestingAuth(repo, demoEmails)
      : automatic
      ? AutomaticTestingAuth(repo)
      : testing
      ? TestingAuth(repo)
      : FakeAuthService(repo);
  final coupons = FakeCouponService(repo);
  final selfies = MemorySelfieStore();
  final links = StreamController<Uri>.broadcast();
  addTearDown(links.close);
  MealDeskScreen.scannerOverride = const SizedBox.expand();
  addTearDown(() => MealDeskScreen.scannerOverride = null);
  // Camera permission is answered "denied" (no camera in widget tests).
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async => switch (call.method) {
      'requestPermissions' => {1: 0},
      'checkPermissionStatus' => 0,
      _ => null,
    },
  );
  await tester.pumpWidget(
    ConeApp(
      repository: repo,
      auth: auth,
      coupons: coupons,
      selfies: selfies,
      session: session,
      initialLink: Future.value(null),
      incomingLinks: links.stream,
    ),
  );
  await tester.pumpAndSettle();
  return Harness(repo, session, auth, coupons, selfies, links);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    // Lazily built list items appear only once scrolled into view.
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

/// Fails if any visible text still carries prototype wording.
void expectNoPrototypeWording(WidgetTester tester) {
  final banned = RegExp(
    r'(demo|fictional|illustrative|not valid|not redeemable|workbook)',
    caseSensitive: false,
  );
  final texts = <String>[
    for (final w in tester.widgetList<Text>(find.byType(Text)))
      w.data ?? w.textSpan?.toPlainText() ?? '',
  ];
  for (final t in texts) {
    expect(banned.hasMatch(t), isFalse, reason: 'Unexpected wording: "$t"');
  }
}

Future<void> fillLogin(WidgetTester tester, Person p, {String? mobile}) async {
  await tester.enterText(find.byKey(const Key('nameField')), p.fullName);
  await tester.enterText(find.byKey(const Key('emailField')), p.email);
  await tester.enterText(
    find.byKey(const Key('mobileField')),
    mobile ?? p.mobile,
  );
  await tapKey(tester, 'continueButton');
}

/// Logs in as [p] and lands on the dashboard (skipping the selfie).
Future<void> signInAs(WidgetTester tester, Harness h, Person p) async {
  await fillLogin(tester, p);
  expect(find.byType(CheckEmailScreen), findsOneWidget);
  await h.tapEmailLink(tester);
  expect(find.byType(SelfieScreen), findsOneWidget);
  await tapKey(tester, 'skipSelfie');
  expect(find.byType(DashboardScreen), findsOneWidget);
}

Color screenBackground(WidgetTester tester) => Theme.of(
  tester.element(find.byType(DashboardScreen)),
).scaffoldBackgroundColor;

void main() {
  testWidgets(
    'public branding updates login, dashboard and browser title without a new login',
    (tester) async {
      final repo = BrandedRepository();
      addTearDown(repo.changes.close);
      final h = await pumpApp(tester, automatic: true, repository: repo);
      repo.changes.add(const AppBranding(applicationName: 'Aurora Congress'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'Aurora Congress',
      );
      expect(find.textContaining('Aurora Congress'), findsWidgets);
      await fillLogin(tester, h.repo.byRole(Role.attendee));
      await tapKey(tester, 'skipSelfie');
      expect(find.text('Aurora Congress'), findsOneWidget);
      repo.changes.add(const AppBranding(applicationName: 'Summit Congress'));
      await tester.pumpAndSettle();
      expect(find.text('Summit Congress'), findsOneWidget);
      expect(find.text('Aurora Congress'), findsNothing);
      expect(h.session.person?.role, Role.attendee);
    },
  );

  for (final role in Role.values) {
    testWidgets('${role.name}: OTP verification precedes role navigation', (
      tester,
    ) async {
      final h = await pumpApp(tester, otpLogin: true);
      final person = h.repo.byRole(role);
      await fillLogin(tester, person);
      expect(h.session.person, isNull);
      expect(find.byKey(const Key('emailOtpField')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('emailOtpField')), '123456');
      await tapKey(tester, 'verifyEmailOtp');
      expect(h.session.person?.email, person.email);
      expect(h.auth.sent, isEmpty);
      await tapKey(tester, 'skipSelfie');
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byKey(Key('roleBadge-${role.name}')), findsOneWidget);
    });
  }
  testWidgets('OTP resend respects countdown and clears the old code', (
    tester,
  ) async {
    final h = await pumpApp(tester, otpLogin: true);
    await fillLogin(tester, h.repo.byRole(Role.attendee));
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('resendLink')),
    );
    expect(button.onPressed, isNull);
    await tester.enterText(find.byKey(const Key('emailOtpField')), '999999');
    await tester.pump(const Duration(seconds: 61));
    await tapKey(tester, 'resendLink');
    expect((h.auth as OtpTestingAuth).requests, 2);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('emailOtpField')))
          .controller!
          .text,
      isEmpty,
    );
    expect(h.session.person, isNull);
  });
  testWidgets('unknown details show not-found and request no code', (
    tester,
  ) async {
    final h = await pumpApp(tester, otpLogin: true);
    await fillLogin(tester, h.repo.byRole(Role.attendee), mobile: '9000000000');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(CheckEmailScreen), findsNothing);
    expect(find.byKey(const Key('loginError')), findsOneWidget);
    expect(find.text('User data not found in system.'), findsOneWidget);
    expect((h.auth as OtpTestingAuth).requests, 0);
    expect(h.session.person, isNull);
  });
  testWidgets('OTP screen confirms the code was sent', (tester) async {
    final h = await pumpApp(tester, otpLogin: true);
    await fillLogin(tester, h.repo.byRole(Role.attendee));
    expect(find.textContaining('We sent a six-digit code'), findsOneWidget);
    expect(find.textContaining('If your details match'), findsNothing);
  });
  testWidgets('wrong OTP cannot open a dashboard', (tester) async {
    final h = await pumpApp(tester, otpLogin: true);
    await fillLogin(tester, h.repo.byRole(Role.attendee));
    await tester.enterText(find.byKey(const Key('emailOtpField')), '000000');
    await tapKey(tester, 'verifyEmailOtp');
    expect(h.session.person, isNull);
    expect(find.text('Invalid or expired code.'), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
  });

  testWidgets('login has only three identity fields and no password', (
    tester,
  ) async {
    await pumpApp(tester, demoEmails: {});
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.byKey(const Key('passwordField')), findsNothing);
    expect(find.textContaining('assword'), findsNothing);
  });
  testWidgets('demo accounts continue without an email code', (tester) async {
    final repo = FakeRepository();
    final demo = repo.byRole(Role.attendee);
    final h = await pumpApp(tester, repository: repo, demoEmails: {demo.email});
    await fillLogin(tester, demo);
    expect((h.auth as MixedTestingAuth).requests, 0);
    expect(find.byKey(const Key('emailOtpField')), findsNothing);
    expect(h.session.person?.email, demo.email);
    expect(find.byType(SelfieScreen), findsOneWidget);
  });
  testWidgets('other registrations must enter the emailed code', (
    tester,
  ) async {
    final repo = FakeRepository();
    final person = repo.byRole(Role.presenter);
    final h = await pumpApp(
      tester,
      repository: repo,
      demoEmails: {repo.byRole(Role.attendee).email},
    );
    await fillLogin(tester, person);
    expect((h.auth as MixedTestingAuth).requests, 1);
    expect(h.session.person, isNull);
    await tester.enterText(find.byKey(const Key('emailOtpField')), '000000');
    await tapKey(tester, 'verifyEmailOtp');
    expect(h.session.person, isNull);
    await tester.enterText(find.byKey(const Key('emailOtpField')), '123456');
    await tapKey(tester, 'verifyEmailOtp');
    expect(h.session.person?.email, person.email);
    expect(find.byType(SelfieScreen), findsOneWidget);
  });
  for (final role in Role.values) {
    testWidgets(
      '${role.name}: Continue skips all verification and opens the next step',
      (tester) async {
        final h = await pumpApp(tester, automatic: true);
        final person = h.repo.byRole(role);
        await fillLogin(tester, person);
        expect(h.auth.sent, isEmpty);
        expect(find.byType(CheckEmailScreen), findsNothing);
        expect(find.byKey(const Key('verifyEmail')), findsNothing);
        expect(find.byKey(const Key('verificationLink')), findsNothing);
        expect(h.session.person?.email, person.email);
        expect(find.byType(SelfieScreen), findsOneWidget);
        await tapKey(tester, 'skipSelfie');
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byKey(Key('roleBadge-${role.name}')), findsOneWidget);
      },
    );
  }
  testWidgets('automatic Continue rejects mismatched registration details', (
    tester,
  ) async {
    final h = await pumpApp(tester, automatic: true);
    await fillLogin(
      tester,
      h.repo.byRole(Role.presenter),
      mobile: '9876543299',
    );
    expect(h.session.person, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const Key('loginError')), findsOneWidget);
    expect(h.auth.sent, isEmpty);
  });

  for (final role in Role.values) {
    testWidgets(
      '${role.name}: in-app verification without an incoming email link',
      (tester) async {
        final h = await pumpApp(tester, testing: true);
        final person = h.repo.byRole(role);
        await fillLogin(tester, person);
        expect(find.textContaining('no email was sent'), findsOneWidget);
        expect(find.byKey(const Key('verificationLink')), findsOneWidget);
        expect(find.textContaining('Open the email'), findsNothing);
        await tapKey(tester, 'verifyEmail');
        expect(h.session.person?.email, person.email);
        expect(find.byType(SelfieScreen), findsOneWidget);
      },
    );
  }

  testWidgets('login is one form for every role, with no sign-up', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Conference sign-in'), findsOneWidget);
    expect(
      find.text('CONE · Conference Operations & Networking Environment'),
      findsOneWidget,
    );
    expectNoPrototypeWording(tester);
    expect(
      find.textContaining(
        RegExp('sign up|create account', caseSensitive: false),
      ),
      findsNothing,
    );
    await tapKey(tester, 'continueButton');
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text('Enter your mobile number'), findsOneWidget);
    expect(find.byType(CheckEmailScreen), findsNothing);
  });

  testWidgets('a wrong mobile number is rejected after the link', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    await fillLogin(tester, h.repo.byRole(Role.speaker), mobile: '9123456780');
    await h.tapEmailLink(tester);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.byType(SelfieScreen), findsNothing);
    expect(find.textContaining('does not match'), findsOneWidget);
    expect(h.session.person, isNull);
  });

  testWidgets('presenter journey: link, selfie saved, dashboard, sign out', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    final p = h.repo.byRole(Role.presenter);

    await fillLogin(tester, p);
    expect(find.text('We sent you a sign-in link'), findsOneWidget);
    expect(h.auth.sent.single.email, p.email);
    await h.tapEmailLink(tester);

    // Camera denied in tests: continue without a photo.
    expect(find.text('Allow camera'), findsOneWidget);
    expect(find.textContaining('saved only on this phone'), findsOneWidget);
    await tapKey(tester, 'skipSelfie');

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text(p.fullName), findsOneWidget);
    expect(find.byKey(const Key('roleBadge-presenter')), findsOneWidget);
    expect(screenBackground(tester), Role.presenter.background);
    expectNoPrototypeWording(tester);

    await tapKey(tester, 'openPaper');
    expect(find.byKey(const Key('paperTitle')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapKey(tester, 'openSchedule');
    await scrollTo(tester, find.text('Your presentation'));
    expect(find.text('Your presentation'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapKey(tester, 'openQrPass');
    final qr = tester.widget<PassQr>(find.byType(PassQr));
    expect(qr.payload, p.passId);
    expect(qr.payload, isNot(contains('@')));
    expect(qr.payload, isNot(contains(p.mobile)));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Coupons go "Used" live when a volunteer serves them.
    await tapKey(tester, 'openCoupons');
    final lunch = p.coupons.firstWhere(
      (c) => c.meal == 'Lunch' && c.day == 'Day 1',
    );
    await tapKey(tester, 'coupon-${lunch.couponId}');
    expect(find.text('VALID — SHOW TO VOLUNTEER'), findsOneWidget);
    await h.coupons.redeem(IssuedCoupon.of(p, lunch));
    await tester.pumpAndSettle();
    expect(find.text('USED AT 13:05'), findsOneWidget);
    expect(find.byKey(const Key('couponQr')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapKey(tester, 'signOutButton');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(h.session.person, isNull);
    expect(h.auth.signOuts, 1);
  });

  testWidgets('a stored selfie skips the selfie step and shows on profile', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    final p = h.repo.byRole(Role.attendee);
    // A real 1×1 PNG so the avatar can decode it.
    final jpeg = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    await h.selfies.save(p.email, jpeg);

    await fillLogin(tester, p);
    await h.tapEmailLink(tester);
    expect(find.byType(SelfieScreen), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(h.session.selfie, jpeg);

    // Signing out removes it from the phone.
    await tapKey(tester, 'signOutButton');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(await h.selfies.load(p.email), isNull);
  });

  for (final role in Role.values) {
    testWidgets('${role.label}: own colour and role-specific dashboard', (
      tester,
    ) async {
      final h = await pumpApp(tester);
      final p = h.repo.byRole(role);
      await signInAs(tester, h, p);

      expect(find.byKey(Key('roleBadge-${role.name}')), findsOneWidget);
      expect(screenBackground(tester), role.background);
      expectNoPrototypeWording(tester);

      Finder card(String key) => find.byKey(Key(key), skipOffstage: false);
      expect(
        card('openMealDesk'),
        role.isStaff ? findsOneWidget : findsNothing,
      );
      expect(
        card('openPeople'),
        role == Role.organiser ? findsOneWidget : findsNothing,
      );
      expect(
        card('talkCard'),
        role == Role.speaker ? findsOneWidget : findsNothing,
      );
      expect(
        card('hostCard'),
        role == Role.vip ? findsOneWidget : findsNothing,
      );
      expect(card('dutiesCard'), role.isStaff ? findsOneWidget : findsNothing);
      expect(
        card('openPaper'),
        role == Role.presenter ? findsOneWidget : findsNothing,
      );
    });
  }

  test('every role has a distinct background colour', () {
    expect(
      Role.values.map((r) => r.background.toARGB32()).toSet(),
      hasLength(Role.values.length),
    );
  });

  testWidgets('volunteer serves a coupon once; a second scan is rejected', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    final vip = h.repo.byRole(Role.vip);
    final breakfast = vip.coupons.first;
    await signInAs(tester, h, h.repo.byRole(Role.volunteer));
    await tapKey(tester, 'openMealDesk');
    expect(find.byType(MealDeskScreen), findsOneWidget);

    Future<void> scan(String code) async {
      await tester.enterText(find.byKey(const Key('manualCouponId')), code);
      await tapKey(tester, 'checkManualCoupon');
      expect(find.byType(CouponCheckScreen), findsOneWidget);
    }

    await scan('MEAL-D9-XXX-NOTREAL');
    expect(find.byKey(const Key('couponUnknown')), findsOneWidget);
    await tapKey(tester, 'couponBack');

    await scan(breakfast.couponId);
    expect(find.byKey(const Key('couponValid')), findsOneWidget);
    expect(find.text(vip.fullName), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    await tapKey(tester, 'markServed');
    expect(find.byKey(const Key('couponServed')), findsOneWidget);
    await tapKey(tester, 'couponBack');

    await scan(breakfast.couponId.toLowerCase());
    expect(find.byKey(const Key('couponAlreadyUsed')), findsOneWidget);
    expect(find.byKey(const Key('markServed')), findsNothing);
  });

  testWidgets('organiser sees the overview and the people list', (
    tester,
  ) async {
    final h = await pumpApp(tester);
    h.repo.meals = 4;
    await signInAs(tester, h, h.repo.byRole(Role.organiser));
    expect(find.text('6'), findsWidgets); // registered
    expect(
      find.descendant(
        of: find.byKey(const Key('mealsServed')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'openPeople');
    expect(find.byType(PeopleScreen), findsOneWidget);
    for (final p in h.repo.all) {
      expect(find.text(p.fullName), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'VIP'));
    await tester.pumpAndSettle();
    expect(find.text(h.repo.byRole(Role.vip).fullName), findsOneWidget);
    expect(find.text(h.repo.byRole(Role.speaker).fullName), findsNothing);
  });
}
