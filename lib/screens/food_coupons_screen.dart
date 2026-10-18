import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../coupons/coupon_service.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// A person's meal coupons with live "Valid / Used" status.
class FoodCouponsScreen extends StatelessWidget {
  const FoodCouponsScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final coupons = person.coupons;
    return Scaffold(
      appBar: AppBar(title: const Text('Food coupons')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          const Text(
            'Show the coupon QR at the meal counter. A volunteer scans it '
            'and marks it served; each coupon works once.',
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (coupons.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                'No food coupons are available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          for (final coupon in coupons) ...[
            _CouponCard(person: person, coupon: coupon),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

IconData _mealIcon(String meal) => switch (meal.toLowerCase()) {
  'breakfast' => Icons.free_breakfast_outlined,
  'dinner' => Icons.dinner_dining_outlined,
  _ => Icons.lunch_dining_outlined,
};

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.person, required this.coupon});

  final Person person;
  final FoodCoupon coupon;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CouponStatus>(
      stream: AppScope.of(context).coupons.watch(coupon.couponId),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final used = status?.used ?? false;
        return Card(
          key: Key('coupon-${coupon.couponId}'),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CouponQrScreen(person: person, coupon: coupon),
              ),
            ),
            child: Opacity(
              opacity: used ? 0.55 : 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: used
                          ? const SizedBox(
                              width: 72,
                              height: 72,
                              child: Icon(
                                Icons.check_circle,
                                size: 40,
                                color: AppColors.textMuted,
                              ),
                            )
                          : QrImageView(
                              data: coupon.couponId,
                              size: 72,
                              padding: EdgeInsets.zero,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppColors.navy,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: AppColors.navy,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _mealIcon(coupon.meal),
                                size: 20,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${coupon.meal} · ${coupon.day}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coupon.window,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coupon.couponId,
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _StatusChip(status: status),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final CouponStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      return const LabelChip(
        label: 'Checking…',
        background: Color(0xFFEFF2F6),
        foreground: AppColors.textMuted,
      );
    }
    if (s.used) {
      return LabelChip(
        label: s.usedAt == null ? 'Used' : 'Used at ${formatTime(s.usedAt!)}',
        icon: Icons.check,
        background: const Color(0xFFEFF2F6),
        foreground: AppColors.textMuted,
      );
    }
    return const LabelChip(label: 'Valid', icon: Icons.verified_outlined);
  }
}

/// Full-screen coupon QR for the volunteer to scan. Updates live when served.
class CouponQrScreen extends StatelessWidget {
  const CouponQrScreen({super.key, required this.person, required this.coupon});

  final Person person;
  final FoodCoupon coupon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${coupon.meal} coupon')),
      body: StreamBuilder<CouponStatus>(
        stream: AppScope.of(context).coupons.watch(coupon.couponId),
        builder: (context, snapshot) {
          final status = snapshot.data;
          final used = status?.used ?? false;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: used ? AppColors.textMuted : AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Column(
                        children: [
                          Icon(
                            _mealIcon(coupon.meal),
                            color: AppColors.tealBright,
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${coupon.meal} · ${coupon.day}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            coupon.window,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            person.fullName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: used
                                ? const Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 120,
                                      color: AppColors.textMuted,
                                    ),
                                  )
                                : QrImageView(
                                    key: const Key('couponQr'),
                                    data: coupon.couponId,
                                    size: 240,
                                    backgroundColor: Colors.white,
                                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: AppColors.navy,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: AppColors.navy,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            coupon.couponId,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: const Key('couponStatusBand'),
                      width: double.infinity,
                      color: used ? AppColors.warningFg : AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        status == null
                            ? 'Checking…'
                            : used
                            ? (status.usedAt == null
                                  ? 'USED'
                                  : 'USED AT ${formatTime(status.usedAt!)}')
                            : 'VALID — SHOW TO VOLUNTEER',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.hasError) ...[
                const SizedBox(height: 14),
                const NoticeBanner(
                  tone: NoticeTone.warning,
                  message:
                      'Could not load the latest status. Check your internet '
                      'connection.',
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
