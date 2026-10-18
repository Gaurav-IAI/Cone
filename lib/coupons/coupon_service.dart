import '../data/models.dart';

/// Live state of one meal coupon.
class CouponStatus {
  const CouponStatus.valid() : used = false, usedAt = null, usedBy = null;

  const CouponStatus.used({this.usedAt, this.usedBy}) : used = true;

  final bool used;
  final DateTime? usedAt;

  /// Email of the volunteer who served the meal (visible to volunteers only).
  final String? usedBy;
}

sealed class RedeemResult {
  const RedeemResult();
}

class Redeemed extends RedeemResult {
  const Redeemed();
}

class AlreadyUsed extends RedeemResult {
  const AlreadyUsed(this.status);
  final CouponStatus status;
}

class RedeemFailed extends RedeemResult {
  const RedeemFailed(this.message);
  final String message;
}

/// Coupon redemption. Implemented on Cloud Firestore in
/// [FirestoreCouponService]; tests use a fake.
abstract class CouponService {
  /// Live status of [couponId] for its owner or a volunteer.
  Stream<CouponStatus> watch(String couponId);

  /// Marks [issued] as served. Succeeds at most once per coupon.
  Future<RedeemResult> redeem(IssuedCoupon issued);
}

/// "13:05" style time for status labels.
String formatTime(DateTime t) {
  final local = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}
