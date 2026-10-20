import 'package:flutter/widgets.dart';

class AppBranding {
  const AppBranding({this.applicationName = 'CONE', this.logoUrl});
  final String applicationName;
  final String? logoUrl;
  factory AppBranding.fromJson(Map<String, dynamic>? data) {
    final name = data?['applicationName'];
    final raw = data?['logoUrl'];
    final uri = raw is String ? Uri.tryParse(raw) : null;
    return AppBranding(
      applicationName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : 'CONE',
      logoUrl:
          uri != null &&
              ['http', 'https'].contains(uri.scheme) &&
              uri.host.isNotEmpty
          ? uri.toString()
          : null,
    );
  }
}

abstract interface class BrandingSource {
  Stream<AppBranding> watchBranding();
}

class BrandingScope extends InheritedWidget {
  const BrandingScope({
    super.key,
    required this.branding,
    required super.child,
  });
  final AppBranding branding;
  static AppBranding of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrandingScope>()?.branding ??
      const AppBranding();
  @override
  bool updateShouldNotify(BrandingScope oldWidget) =>
      branding.applicationName != oldWidget.branding.applicationName ||
      branding.logoUrl != oldWidget.branding.logoUrl;
}

String appName(BuildContext context) =>
    BrandingScope.of(context).applicationName;
