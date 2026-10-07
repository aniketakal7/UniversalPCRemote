import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:android_app/main.dart';
import 'package:android_app/protocol/models.dart';

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
  });
}
