import '../app/branding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cone_repository.dart';
import 'models.dart';

/// Reads `conference/main`, `people/{email}` and `couponIndex/{couponId}`.
/// Access is limited by firestore.rules (own record; staff/organiser extras).
class FirestoreConeRepository implements ConeRepository, BrandingSource {
  FirestoreConeRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  Conference? _conference;

  @override
  Stream<AppBranding> watchBranding() => _db
      .doc('conference/branding')
      .snapshots()
      .map((snapshot) => AppBranding.fromJson(snapshot.data()));

  @override
  Future<Conference> conference() async {
    final cached = _conference;
    if (cached != null) return cached;
    final snap = await _db.doc('conference/main').get();
    final data = snap.data();
    if (data == null) throw DataException('Conference information is missing');
    return _conference = Conference.fromJson(data);
  }

  @override
  Future<Person?> person(String email) async {
    final id = email.trim().toLowerCase();
    final snap = await _db.doc('people/$id').get();
    final data = snap.data();
    return data == null ? null : Person.fromJson(data, 'people/$id');
  }

  @override
  Future<IssuedCoupon?> coupon(String couponId) async {
    final id = couponId.trim().toUpperCase();
    if (id.isEmpty || id.contains('/')) return null;
    final snap = await _db.doc('couponIndex/$id').get();
    final data = snap.data();
    return data == null ? null : IssuedCoupon.fromJson(data, 'couponIndex/$id');
  }

  @override
  Future<List<Person>> people() async {
    final snap = await _db.collection('people').orderBy('fullName').get();
    return [
      for (final doc in snap.docs)
        Person.fromJson(doc.data(), 'people/${doc.id}'),
    ];
  }

  @override
  Future<Map<Role, int>> roleCounts() async {
    final people = _db.collection('people');
    final counts = await Future.wait([
      for (final role in Role.values)
        people.where('role', isEqualTo: role.name).count().get(),
    ]);
    return {
      for (var i = 0; i < Role.values.length; i++)
        Role.values[i]: counts[i].count ?? 0,
    };
  }

  @override
  Future<int> mealsServed() async =>
      (await _db.collection('mealRedemptions').count().get()).count ?? 0;
}
