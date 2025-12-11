import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:treasure_hunt_rpg/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const TreasureHuntApp());

    // Verify that the app loads without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
