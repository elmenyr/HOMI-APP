// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// ignore_for_file: unused_import, directives_ordering, lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homi/app.dart';
import 'package:homi/app_data.dart';
import 'package:homi/login_page.dart';

void main() {
  group('App Tests', () {
    testWidgets('AppLoader shows loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(const LoginPage());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('App shows login page when not authenticated', (WidgetTester tester) async {
      await tester.pumpWidget(const App(data: AppData()));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('Login page has required fields', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Navigation bar has correct items', (WidgetTester tester) async {
      await tester.pumpWidget(const App(data: AppData()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });
}
