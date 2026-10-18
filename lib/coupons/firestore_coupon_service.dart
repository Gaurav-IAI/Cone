import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/models.dart';
import 'coupon_service.dart';

/// Stores one document per served meal at `mealRedemptions/{couponId}`.
///
/// Security rules (firestore.rules) let only volunteers create these
/// documents, never update or delete them, and let a participant read only
/// their own — so a coupon can be used once and stays used.
class FirestoreCouponService implements CouponService {
  FirestoreCouponService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const collection = 'mealRedemptions';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>> _ref(String couponId) =>
      _firestore.collection(collection).doc(couponId.toUpperCase());

  static CouponStatus _statusOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return const CouponStatus.valid();
    final data = snap.data()!;
    final at = data['redeemedAt'];
    return CouponStatus.used(
      usedAt: at is Timestamp ? at.toDate() : null,
      usedBy: data['redeemedBy'] as String?,
    );
  }

  @override
  Stream<CouponStatus> watch(String couponId) =>
      _ref(couponId).snapshots().map(_statusOf);

  @override
  Future<RedeemResult> redeem(IssuedCoupon issued) async {
    final volunteer = _auth.currentUser?.email;
    if (volunteer == null) return const RedeemFailed('Not signed in.');
    final ref = _ref(issued.coupon.couponId);
    try {
      // Transactions need the server, so an offline phone cannot report a
      // false "served".
      return await _firestore.runTransaction<RedeemResult>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return AlreadyUsed(_statusOf(snap));
        tx.set(ref, {
          'couponId': issued.coupon.couponId.toUpperCase(),
          'registrationId': issued.registrationId,
          'participantEmail': issued.ownerEmail,
          'meal': issued.coupon.meal,
          'day': issued.coupon.day,
          'redeemedAt': FieldValue.serverTimestamp(),
          'redeemedBy': volunteer.toLowerCase(),
        });
        return const Redeemed();
      });
    } on FirebaseException catch (e) {
      return RedeemFailed(switch (e.code) {
        'permission-denied' =>
          'This account is not allowed to mark coupons, or the coupon was '
              'already used.',
        'unavailable' => 'No internet connection. Try again.',
        _ => 'Could not save (${e.code}). Try again.',
      });
    }
  }
}
