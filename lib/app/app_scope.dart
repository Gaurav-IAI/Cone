import 'package:flutter/widgets.dart';

import '../auth/participant_auth_service.dart';
import '../coupons/coupon_service.dart';
import '../data/cone_repository.dart';
import 'app_session.dart';
import 'selfie_store.dart';

/// Makes the app's services available to every screen.
class AppScope extends InheritedNotifier<AppSession> {
  const AppScope({
    super.key,
    required this.repository,
    required this.auth,
    required this.coupons,
    required this.selfies,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);

  final ConeRepository repository;
  final AuthService auth;
  final CouponService coupons;
  final SelfieStore selfies;

  AppSession get session => notifier!;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found above this widget');
    return scope!;
  }
}
