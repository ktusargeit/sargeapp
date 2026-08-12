import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarge_depo_app/core/theme/app_colors.dart';
import 'package:sarge_depo_app/core/theme/app_theme.dart';

void main() {
  testWidgets('SARGE theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Center(child: Text('SARGE')),
        ),
      ),
    );
    expect(find.text('SARGE'), findsOneWidget);
    expect(AppColors.sargeGold, isNotNull);
  });
}