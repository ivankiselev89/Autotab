// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autotab/main.dart';

void main() {
  testWidgets('App launches with home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(AutotabApp());

    // Verify that the home screen is displayed
    expect(find.text('Welcome to Autotab'), findsOneWidget);
    expect(find.text('Automatic Audio Transcription Tool'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);
  });

  testWidgets('Navigation to record screen works', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(AutotabApp());

    // Find and tap the Start Recording button
    await tester.tap(find.text('Start Recording'));
    await tester.pumpAndSettle();

    // Verify that the record screen is displayed
    expect(find.text('Record Screen'), findsOneWidget);
    expect(find.text('Ready to Record'), findsOneWidget);
  });
}
