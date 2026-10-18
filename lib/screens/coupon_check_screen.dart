import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/roles.dart';
import '../app/theme.dart';
import '../coupons/coupon_service.dart';
import '../data/models.dart';
import '../widgets/common.dart';

/// What a volunteer sees after scanning: who the coupon belongs to, whether it
/// is still valid, and a "Done" button that marks it served.
class CouponCheckScreen extends StatefulWidget {
  const CouponCheckScreen({super.key, required this.couponId});

  final String couponId;

  @override
  State<CouponCheckScreen> createState() => _CouponCheckScreenState();
}

class _CouponCheckScreenState extends State<CouponCheckScreen> {
  Future<IssuedCoupon?>? _issued;
  bool _saving = false;
  RedeemResult? _result;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _issued ??= AppScope.of(context).repository.coupon(widget.couponId);
  }

  Future<void> _markServed(IssuedCoupon issued) async {
    setState(() => _saving = true);
    final result = await AppScope.of(context).coupons.redeem(issued);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal coupon')),
      body: FutureBuilder<IssuedCoupon?>(
        future: _issued,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final issued = snapshot.data;
          if (issued == null) {
            return _Verdict(
              key: const Key('couponUnknown'),
              color: AppColors.warningFg,
              icon: Icons.block,
              title: 'Not a valid meal coupon',
              subtitle: widget.couponId,
              child: _BackButton(),
            );
          }
          return StreamBuilder<CouponStatus>(
            stream: AppScope.of(context).coupons.watch(issued.coupon.couponId),
            builder: (context, status) {
              if (!status.hasData && !status.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildFor(issued, status.data, status.error);
            },
          );
        },
      ),
    );
  }

  Widget _buildFor(IssuedCoupon issued, CouponStatus? status, Object? error) {
    final details = _CouponDetails(issued: issued);
    if (_result is Redeemed) {
      return _Verdict(
        key: const Key('couponServed'),
        color: AppColors.teal,
        icon: Icons.check_circle,
        title: 'Served',
        subtitle: '${issued.coupon.meal} · ${issued.coupon.day}',
        child: Column(
          children: [
            details,
            const SizedBox(height: 16),
            _BackButton(label: 'Scan next'),
          ],
        ),
      );
    }
    final alreadyUsed = _result is AlreadyUsed || (status?.used ?? false);
    if (alreadyUsed) {
      final s = _result is AlreadyUsed
          ? (_result as AlreadyUsed).status
          : status!;
      return _Verdict(
        key: const Key('couponAlreadyUsed'),
        color: AppColors.warningFg,
        icon: Icons.cancel,
        title: 'Already used',
        subtitle: [
          if (s.usedAt != null) 'at ${formatTime(s.usedAt!)}',
          if (s.usedBy != null) 'by ${s.usedBy}',
        ].join(' '),
        child: Column(
          children: [
            details,
            const SizedBox(height: 16),
            _BackButton(label: 'Scan next'),
          ],
        ),
      );
    }
    final failure = _result is RedeemFailed
        ? (_result as RedeemFailed).message
        : (error != null
              ? 'Could not check this coupon. Check the connection.'
              : null);
    return _Verdict(
      key: const Key('couponValid'),
      color: AppColors.teal,
      icon: Icons.verified,
      title: 'Valid',
      subtitle: '${issued.coupon.meal} · ${issued.coupon.day}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          details,
          if (failure != null) ...[
            const SizedBox(height: 12),
            NoticeBanner(tone: NoticeTone.warning, message: failure),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('markServed'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: _saving ? null : () => _markServed(issued),
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.done),
            label: const Text('Done — mark as served'),
          ),
          const SizedBox(height: 8),
          _BackButton(label: 'Cancel'),
        ],
      ),
    );
  }
}

class _CouponDetails extends StatelessWidget {
  const _CouponDetails({required this.issued});

  final IssuedCoupon issued;

  @override
  Widget build(BuildContext context) {
    final c = issued.coupon;
    return SectionCard(
      child: Column(
        children: [
          InfoRow(label: 'Name', value: issued.ownerName),
          InfoRow(label: 'Role', value: issued.role.label),
          InfoRow(label: 'Registration', value: issued.registrationId),
          InfoRow(label: 'Meal', value: '${c.meal} · ${c.day}'),
          InfoRow(label: 'Time', value: c.window),
          InfoRow(label: 'Coupon ID', value: c.couponId),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 56),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.label = 'Back'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('couponBack'),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(label),
    );
  }
}
