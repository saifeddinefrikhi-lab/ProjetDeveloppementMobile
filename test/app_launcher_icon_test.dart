import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_classification/core/widgets/app_launcher_icon.dart';

void main() {
  testWidgets('renders the launcher mark at the requested square size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AppLauncherIcon(size: 48))),
    );

    expect(tester.getSize(find.byType(AppLauncherIcon)), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });
}
