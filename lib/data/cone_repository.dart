import 'models.dart';

/// Read access to conference data. Implemented on Cloud Firestore in
/// [FirestoreConeRepository]; tests use an in-memory fake.
abstract class ConeRepository {
  /// Public conference information.
  Future<Conference> conference();

  /// The registration for [email], or null if there is none.
  Future<Person?> person(String email);

  /// The coupon with this ID and its owner (meal-desk staff only).
  Future<IssuedCoupon?> coupon(String couponId);

  /// Everyone registered (organisers only).
  Future<List<Person>> people();

  /// Number of registrations per role (organisers only).
  Future<Map<Role, int>> roleCounts();

  /// Meals served so far (organisers only).
  Future<int> mealsServed();
}
