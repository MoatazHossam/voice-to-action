import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_to_action/app/app.dart';

void main() {
  testWidgets('App boots to the Arabic RTL home screen with both entry points', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('إدخال صوتي'), findsOneWidget);
    expect(find.text('إدخال صورة'), findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
