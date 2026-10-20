import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:usstc_conference/auth/identity_matcher.dart';
import 'package:usstc_conference/auth/participant_auth_service.dart';
import 'package:usstc_conference/coupons/coupon_service.dart';
import 'package:usstc_conference/data/cone_repository.dart';
import 'package:usstc_conference/data/models.dart';

/// The same file the seed tool loads into Firebase.
Map<String, dynamic> readSeed() =>
    jsonDecode(File('tools/seed/seed_data.json').readAsStringSync())
        as Map<String, dynamic>;

/// In-memory repository built from the seed data.
class FakeRepository implements ConeRepository {
  FakeRepository() {
    final seed = readSeed();
    _conference = Conference.fromJson(seed['conference'] as Json);
    _people = [
      for (final p in seed['people'] as List) Person.fromJson(p as Json),
    ];
  }

  late final Conference _conference;
  late final List<Person> _people;
  int meals = 0;

  List<Person> get all => _people;
  Person byRole(Role role) => _people.firstWhere((p) => p.role == role);

  @override
  Future<Conference> conference() async => _conference;

  @override
  Future<Person?> person(String email) async {
    for (final p in _people) {
      if (p.email == email.trim().toLowerCase()) return p;
    }
    return null;
  }

  @override
  Future<IssuedCoupon?> coupon(String couponId) async {
    final id = couponId.trim().toUpperCase();
    for (final p in _people) {
      for (final c in p.coupons) {
        if (c.couponId == id) return IssuedCoupon.of(p, c);
      }
    }
    return null;
  }

  @override
  Future<List<Person>> people() async =>
      [..._people]..sort((a, b) => a.fullName.compareTo(b.fullName));

  @override
  Future<Map<Role, int>> roleCounts() async => {
    for (final r in Role.values) r: _people.where((p) => p.role == r).length,
  };

  @override
  Future<int> mealsServed() async => meals;
}

/// In-memory stand-in for Firebase email-link sign-in.
class FakeAuthService implements AuthService {
  FakeAuthService(this.repository);

  final FakeRepository repository;
  final sent = <LoginDetails>[];
  int signOuts = 0;

  static final sampleLink = Uri.parse(
    'https://conferencemanagement-239a3.firebaseapp.com/__/auth/links'
    '?link=https%3A%2F%2Fexample.com%3FoobCode%3Dabc',
  );

  @override
  Future<void> sendSignInLink(LoginDetails details) async => sent.add(details);

  @override
  bool isSignInLink(Uri link) => link.path == '/__/auth/links';

  @override
  Future<SignInState> completeSignIn(Uri link, {String? email}) async {
    if (sent.isEmpty && email == null) return const EmailNeeded();
    final typed = sent.isEmpty ? null : sent.last;
    final person = await repository.person(email ?? typed!.email);
    if (person == null) return const SignInFailed('No registration was found.');
    // Like the real service: name/mobile are checked only when typed here.
    if (typed != null &&
        !IdentityMatcher.matches(
          typedName: typed.name,
          typedEmail: typed.email,
          typedMobile: typed.mobile,
          recordName: person.fullName,
          recordEmail: person.email,
          recordMobile: person.mobile,
        )) {
      return const SignInFailed(
        'The name or mobile number does not match the registration for this '
        'email.',
      );
    }
    return SignedIn(person);
  }

  @override
  Future<SignInState?> restore() async => null;

  @override
  Future<void> signOut() async => signOuts++;
}

/// In-memory coupon store with live updates.
class FakeCouponService implements CouponService {
  FakeCouponService(this.repository);

  final FakeRepository repository;
  final _status = <String, CouponStatus>{};
  final _changes = StreamController<String>.broadcast();

  @override
  Stream<CouponStatus> watch(String couponId) async* {
    final id = couponId.toUpperCase();
    yield _status[id] ?? const CouponStatus.valid();
    await for (final changed in _changes.stream) {
      if (changed == id) yield _status[id]!;
    }
  }

  @override
  Future<RedeemResult> redeem(IssuedCoupon issued) async {
    final id = issued.coupon.couponId.toUpperCase();
    final current = _status[id];
    if (current != null && current.used) return AlreadyUsed(current);
    _status[id] = CouponStatus.used(
      usedAt: DateTime(2026, 10, 23, 13, 5),
      usedBy: 'volunteer@gmail.com',
    );
    repository.meals++;
    _changes.add(id);
    return const Redeemed();
  }
}
