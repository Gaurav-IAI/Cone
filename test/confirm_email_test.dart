import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usstc_conference/data/models.dart';
import 'package:usstc_conference/screens/selfie_screen.dart';

import 'widget_test.dart' as w;

void main() {
  testWidgets('link opened without a stored email asks for it', (tester) async {
    final h = await w.pumpApp(tester);
    final p = h.repo.byRole(Role.presenter);
    h.auth.sent.clear();
    h.links.add(
      Uri.parse(
        'https://conferencemanagement-239a3.firebaseapp.com/__/auth/links?x=1',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm your email'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('confirmEmailField')), p.email);
    await tester.tap(find.byKey(const Key('confirmEmailContinue')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SelfieScreen), findsOneWidget);
  });
}
