import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/main.dart';
import 'package:android_app/protocol/models.dart';
import 'package:android_app/state/connection_state.dart';

void main() {
  group('Protocol Models Tests', () {
    test('CommandEnvelope generates valid JSON envelope', () {
      final envelope = CommandEnvelope(
        version: 1,
        requestId: 'test-req-123',
        type: CommandTypes.mouseMove,
        timestamp: 1712500000,
        payload: {'dx': 10.5, 'dy': -5.0},
      );

      final json = envelope.toJson();
      expect(json['version'], 1);
      expect(json['requestId'], 'test-req-123');
      expect(json['type'], 'mouse.move');
      expect(json['payload']['dx'], 10.5);

      final encoded = envelope.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['type'], 'mouse.move');
    });

    test('ResponseEnvelope parses success response', () {
      final raw = {
        'version': 1,
        'requestId': 'req-999',
        'type': CommandTypes.systemGetInfo,
        'success': true,
        'data': {'pcName': 'DESKTOP-TEST', 'uptime': '5h'},
        'error': null,
      };

      final resp = ResponseEnvelope.fromJson(raw);
      expect(resp.success, true);
      expect(resp.requestId, 'req-999');
      expect(resp.data['pcName'], 'DESKTOP-TEST');
      expect(resp.error, null);
    });

    test('ResponseEnvelope parses error payload', () {
      final raw = {
        'version': 1,
        'requestId': 'req-error',
        'type': 'mouse.move',
        'success': false,
        'data': null,
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Session is not authenticated.',
        },
      };

      final resp = ResponseEnvelope.fromJson(raw);
      expect(resp.success, false);
      expect(resp.error, isNotNull);
      expect(resp.error!.code, 'UNAUTHORIZED');
      expect(resp.error!.message, 'Session is not authenticated.');
    });

    test('UUID generator produces valid format', () {
      final id = CommandEnvelope.generateId();
      expect(id.length, 36);
      expect(id.split('-').length, 5);
    });
  });

  group('UI Smoke Test', () {
    testWidgets('App renders main screens and title', (WidgetTester tester) async {
      await tester.pumpWidget(const UniversalRemoteApp());
      await tester.pump();

      expect(find.text('Touchpad & Mouse'), findsOneWidget);
      expect(find.text('LEFT CLICK'), findsOneWidget);
      expect(find.text('RIGHT CLICK'), findsOneWidget);
    });

    testWidgets('Remotes and Presentation tabs switch smoothly', (WidgetTester tester) async {
      await tester.pumpWidget(const UniversalRemoteApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on Remotes navigation item
      await tester.tap(find.text('Remotes'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Check Remotes screen tabs
      expect(find.text('App Remotes'), findsOneWidget);
      expect(find.text('Slides Deck'), findsOneWidget);
      expect(find.text('Safe Macros'), findsOneWidget);

      // Tap on Slides Deck
      await tester.tap(find.text('Slides Deck'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Presentation Controller'), findsOneWidget);
      expect(find.text('NEXT SLIDE'), findsOneWidget);
      expect(find.text('PREVIOUS'), findsOneWidget);
    });

    testWidgets('Pairing required triggers 6-digit PIN dialog and buttons', (WidgetTester tester) async {
      final stateManager = ConnectionStateManager();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          stateManager: stateManager,
          isDarkMode: true,
          onToggleTheme: () {},
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Initially no dialog
      expect(find.text('Pairing Security PIN'), findsNothing);

      // Trigger pairingRequired status
      stateManager.setStatusForTesting(AppConnectionStatus.pairingRequired);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog should now be displayed
      expect(find.text('Pairing Security PIN'), findsOneWidget);
      expect(find.text('Enter the 6-digit PIN displayed on Windows PC:'), findsOneWidget);
      expect(find.text('Confirm PIN'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog via Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Pairing Security PIN'), findsNothing);
    });
  });
}
