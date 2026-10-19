import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/auth/direct_demo_auth_service.dart';
import 'package:usstc_conference/auth/participant_auth_service.dart';
import 'package:usstc_conference/data/models.dart';
import 'fakes.dart';

class TestUser extends Fake implements User {
  TestUser(this.uid);
  @override
  final String uid;
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User user;
}

class DirectFirebase extends Fake implements FirebaseAuth {
  DirectFirebase(this.accounts);
  final List accounts;
  int calls = 0;
  int signOuts = 0;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    calls++;
    final account = accounts.singleWhere((a) => a['email'] == email);
    expect(password, account['password']);
    return TestCredential(TestUser(account['uid'] as String));
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config =
      jsonDecode(File('assets/testing/demo_login.json').readAsStringSync())
          as Map;
  for (final role in Role.values) {
    test(
      '${role.name}: direct Firebase login reads live-schema registration without a verification API',
      () async {
        final repo = FakeRepository();
        final person = repo.byRole(role);
        final firebase = DirectFirebase(config['accounts'] as List);
        final service = DirectDemoAuthService(repo, auth: firebase);
        final result = await service.continueWithoutVerification(
          LoginDetails(
            name: person.fullName,
            email: person.email,
            mobile: person.mobile,
          ),
        );
        expect(result, isA<SignedIn>());
        expect((result as SignedIn).person.role, role);
        expect(firebase.calls, 1);
        expect(
          service.isSignInLink(Uri.parse('https://example.test')),
          isFalse,
        );
        expect(
          () => service.sendSignInLink(
            LoginDetails(
              name: person.fullName,
              email: person.email,
              mobile: person.mobile,
            ),
          ),
          throwsA(isA<AuthFailure>()),
        );
      },
    );
  }
  test('incorrect name or mobile is rejected before Firebase login', () async {
    final repo = FakeRepository();
    final firebase = DirectFirebase(config['accounts'] as List);
    final service = DirectDemoAuthService(repo, auth: firebase);
    final result = await service.continueWithoutVerification(
      const LoginDetails(
        name: 'Arav Mehra',
        email: 'presenter@gmail.com',
        mobile: '9876543210',
      ),
    );
    expect(result, isA<SignInFailed>());
    expect(firebase.calls, 0);
  });
}
