import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/app/branding.dart';

void main() {
  test('branding uses safe defaults when missing', () {
    expect(AppBranding.fromJson(null).applicationName, 'CONE');
    expect(AppBranding.fromJson({}).logoUrl, isNull);
  });
  test('branding accepts persisted public name and image URL', () {
    final value = AppBranding.fromJson({
      'applicationName': ' Summit Congress ',
      'logoUrl': 'https://example.org/api/branding/logo/id',
    });
    expect(value.applicationName, 'Summit Congress');
    expect(value.logoUrl, 'https://example.org/api/branding/logo/id');
  });
  test('branding rejects non-web URLs', () {
    for (final url in [
      'javascript:alert(1)',
      'file:///private/logo.png',
      '/relative/logo.png',
    ]) {
      expect(AppBranding.fromJson({'logoUrl': url}).logoUrl, isNull);
    }
  });
}
