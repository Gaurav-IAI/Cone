import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/auth/identity_matcher.dart';

void main() {
  group('IdentityMatcher', () {
    test('normalises mobile numbers', () {
      expect(IdentityMatcher.normalizeMobile('98765 43210'), '9876543210');
      expect(IdentityMatcher.normalizeMobile('+91 98765-43210'), '9876543210');
      expect(IdentityMatcher.normalizeMobile('09876543210'), '9876543210');
      expect(IdentityMatcher.normalizeMobile('12345'), isNull);
      expect(IdentityMatcher.normalizeMobile('5876543210'), isNull);
      expect(IdentityMatcher.normalizeMobile('98765abc10'), isNull);
    });

    test('normalises names and emails', () {
      expect(
        IdentityMatcher.normalizeName('  Dr.  Aarav   MEHRA '),
        'dr aarav mehra',
      );
      expect(IdentityMatcher.normalizeEmail(' A@B.COM '), 'a@b.com');
      expect(IdentityMatcher.isValidEmail('a@b.com'), isTrue);
      expect(IdentityMatcher.isValidEmail('a+vip@b.com'), isTrue);
      expect(IdentityMatcher.isValidEmail('ab.com'), isFalse);
    });

    test('matches only when name, email and mobile all agree', () {
      bool match(String name, String email, String mobile) =>
          IdentityMatcher.matches(
            typedName: name,
            typedEmail: email,
            typedMobile: mobile,
            recordName: 'Prof. Nandini Rautela',
            recordEmail: 'speaker@gmail.com',
            recordMobile: '9876543212',
          );
      expect(
        match('prof nandini rautela', 'Speaker@GMAIL.COM', '+91 98765 43212'),
        isTrue,
      );
      expect(match('Nandini', 'speaker@gmail.com', '9876543212'), isFalse);
      expect(
        match('Prof. Nandini Rautela', 'speaker@gmail.com', '9876543210'),
        isFalse,
      );
    });
  });
}
