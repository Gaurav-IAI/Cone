import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/data/models.dart';

import 'fakes.dart';

void main() {
  final seed = readSeed();
  final repo = FakeRepository();
  final people = repo.all;

  test('seed data is marked as sample data', () {
    expect(seed['isDemo'], isTrue);
    expect(seed['notice'], contains('SAMPLE DATA'));
    for (final p in seed['people'] as List) {
      expect((p as Map)['isDemo'], isTrue, reason: p['email'] as String);
    }
  });

  test('one person per role, each with a unique email and IDs', () {
    expect(people.map((p) => p.role).toSet(), Role.values.toSet());
    expect(people, hasLength(Role.values.length));
    expect(people.map((p) => p.email).toSet(), hasLength(people.length));
    expect(people.map((p) => p.registrationId).toSet(), hasLength(6));
    expect(people.map((p) => p.passId).toSet(), hasLength(6));
    expect(people.map((p) => p.mobile).toSet(), hasLength(6));
  });

  test(
    'all six roles use short emails and retain their names and mobile numbers',
    () {
      const expected = {
        Role.presenter: ['presenter@gmail.com', 'Aarav Mehra', '9876543210'],
        Role.attendee: ['attendee@gmail.com', 'Riya Bhandari', '9876543211'],
        Role.speaker: [
          'speaker@gmail.com',
          'Prof. Nandini Rautela',
          '9876543212',
        ],
        Role.vip: ['vip@gmail.com', 'Dr. Vinod Tamta', '9876543213'],
        Role.organiser: [
          'organizer@gmail.com',
          'Dr. Kavita Negi',
          '9876543214',
        ],
        Role.volunteer: ['volunteer@gmail.com', 'Rohit Bisht', '9876543215'],
      };
      for (final entry in expected.entries) {
        final person = repo.byRole(entry.key);
        expect([person.email, person.fullName, person.mobile], entry.value);
      }
    },
  );

  test('every person has breakfast, lunch and dinner on both days', () {
    final all = <String>{};
    final pattern = RegExp(r'^MEAL-D[12]-(BRK|LUN|DIN)-[A-Z2-9]{8}$');
    for (final p in people) {
      expect(p.coupons, hasLength(6), reason: p.fullName);
      for (final day in ['Day 1', 'Day 2']) {
        expect(p.coupons.where((c) => c.day == day).map((c) => c.meal), [
          'Breakfast',
          'Lunch',
          'Dinner',
        ]);
      }
      for (final c in p.coupons) {
        expect(c.couponId, matches(pattern));
        all.add(c.couponId);
      }
    }
    expect(all, hasLength(36), reason: 'coupon IDs are unique');
  });

  test('coupon lookup resolves the owner and rejects unknown codes', () async {
    final vip = repo.byRole(Role.vip);
    final issued = await repo.coupon(vip.coupons[2].couponId.toLowerCase());
    expect(issued?.ownerEmail, vip.email);
    expect(issued?.role, Role.vip);
    expect(await repo.coupon('MEAL-D1-LUN-NOTISSUED'), isNull);
    expect(await repo.coupon(vip.passId), isNull);
  });

  test('role-specific data is consistent', () async {
    final conference = await repo.conference();
    final presenter = repo.byRole(Role.presenter);
    expect(presenter.paper, isNotNull);
    expect(
      presenter.paper!.authors.where((a) => a.isParticipant).single.name,
      presenter.fullName,
    );
    expect(
      presenter.personalSchedule.single.title,
      contains(presenter.paper!.title),
    );

    final speaker = repo.byRole(Role.speaker);
    expect(speaker.talk, isNotNull);
    expect(
      speaker.personalSchedule.any(
        (i) => i.title.contains(speaker.talk!.title),
      ),
      isTrue,
    );
    expect(
      conference.schedule.any((i) => i.title == speaker.talk!.session),
      isTrue,
      reason: 'the talk slot exists in the conference schedule',
    );

    final vip = repo.byRole(Role.vip);
    final organiser = repo.byRole(Role.organiser);
    expect(vip.host!.name, organiser.fullName);
    expect(vip.host!.mobile, organiser.mobile);

    expect(repo.byRole(Role.volunteer).duties, isNotEmpty);
    expect(repo.byRole(Role.attendee).paper, isNull);
    expect(repo.byRole(Role.attendee).talk, isNull);
    for (final r in Role.values) {
      expect(r.isStaff, r == Role.volunteer || r == Role.organiser);
    }
  });

  test('conference totals add up across disciplines', () async {
    final c = await repo.conference();
    expect(
      c.name,
      '21st Uttarakhand State Science & Technology Congress 2026-27',
    );
    expect(c.disciplines, hasLength(13));
    int sum(int Function(DisciplineSummary) f) =>
        c.disciplines.map(f).reduce((a, b) => a + b);
    expect(sum((d) => d.oral), c.totals.oral);
    expect(sum((d) => d.poster), c.totals.poster);
    expect(sum((d) => d.abstracts), c.totals.abstracts);
  });

  test('personal schedule merges into conference order', () async {
    final c = await repo.conference();
    final items = repo.byRole(Role.speaker).scheduleWith(c);
    final keys = [for (final i in items) '${i.day} ${i.start}'];
    expect(keys, [...keys]..sort());
  });

  test('malformed records fail with the field path', () {
    final bad = Map<String, dynamic>.from((seed['people'] as List).first as Map)
      ..remove('passId');
    expect(
      () => Person.fromJson(bad, 'people/x'),
      throwsA(
        isA<DataException>().having(
          (e) => e.message,
          'message',
          contains('people/x.passId'),
        ),
      ),
    );
    expect(
      () => Person.fromJson({...bad, 'passId': 'P', 'role': 'king'}),
      throwsA(isA<DataException>()),
    );
  });

  test('masks the mobile number', () {
    final p = repo.byRole(Role.presenter);
    expect(p.maskedMobile, endsWith(p.mobile.substring(6)));
    expect(p.maskedMobile, isNot(contains(p.mobile.substring(0, 6))));
  });
}
