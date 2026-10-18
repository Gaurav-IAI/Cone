import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/theme.dart';
import '../widgets/common.dart';
import 'coupon_check_screen.dart';

/// Meal-desk scanner. Scan a coupon QR (or type its ID) to check and serve it.
class MealDeskScreen extends StatefulWidget {
  const MealDeskScreen({super.key, required this.email});

  final String email;

  /// Replaces the camera view in widget tests, where no camera exists.
  @visibleForTesting
  static Widget? scannerOverride;

  @override
  State<MealDeskScreen> createState() => _MealDeskScreenState();
}

class _MealDeskScreenState extends State<MealDeskScreen> {
  MobileScannerController? _controller;
  final _manual = TextEditingController();
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    if (MealDeskScreen.scannerOverride == null) {
      _controller = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _open(String code) async {
    if (_opening || code.trim().isEmpty) return;
    _opening = true;
    await _controller?.stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CouponCheckScreen(couponId: code.trim()),
      ),
    );
    _manual.clear();
    _opening = false;
    if (mounted) await _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal desk')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: AppColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Signed in as ${widget.email}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: AppColors.navy,
                  child:
                      MealDeskScreen.scannerOverride ??
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: (capture) {
                              final value = capture.barcodes.isEmpty
                                  ? null
                                  : capture.barcodes.first.rawValue;
                              if (value != null) _open(value);
                            },
                            errorBuilder: (context, error) => Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  error.errorCode ==
                                          MobileScannerErrorCode
                                              .permissionDenied
                                      ? 'Allow camera access in Settings to '
                                            'scan coupons, or type the coupon '
                                            'ID below.'
                                      : 'The camera could not start. Type the '
                                            'coupon ID below.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          const _ScanFrame(),
                        ],
                      ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Point the camera at the meal coupon QR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            SectionCard(
              title: 'OR ENTER THE COUPON ID',
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('manualCouponId'),
                      controller: _manual,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'MEAL-D1-LUN-…',
                        isDense: true,
                      ),
                      onSubmitted: _open,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    key: const Key('checkManualCoupon'),
                    onPressed: () => _open(_manual.text),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.66,
        heightFactor: 0.66,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.tealBright, width: 3),
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
