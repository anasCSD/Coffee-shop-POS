import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebox_coffee/screens/home_screen.dart';

void main() {
  testWidgets('home screen fits on a phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.2),
          ),
          child: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
