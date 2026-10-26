import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/domain/entities/content.dart';

void main() {
  group('Content totalPurchase parsing and serialization', () {
    test('parses integer totalPurchase correctly', () {
      final json = {
        'id': 1,
        'title': 'Test Movie',
        'totalPurchase': 125,
      };
      final content = Content.fromJson(json);
      expect(content.totalPurchase, equals(125));
    });

    test('parses 0 totalPurchase correctly', () {
      final json = {
        'id': 2,
        'title': 'Zero Purchase Movie',
        'totalPurchase': 0,
      };
      final content = Content.fromJson(json);
      expect(content.totalPurchase, equals(0));
    });

    test('handles null totalPurchase gracefully', () {
      final json = {
        'id': 3,
        'title': 'Null Purchase Movie',
        'totalPurchase': null,
      };
      final content = Content.fromJson(json);
      expect(content.totalPurchase, isNull);
    });

    test('handles missing totalPurchase field gracefully', () {
      final json = {
        'id': 4,
        'title': 'Missing Field Movie',
      };
      final content = Content.fromJson(json);
      expect(content.totalPurchase, isNull);
    });

    test('handles string and double totalPurchase values safely', () {
      final jsonString = {
        'id': 5,
        'totalPurchase': '42',
      };
      final contentFromString = Content.fromJson(jsonString);
      expect(contentFromString.totalPurchase, equals(42));

      final jsonDouble = {
        'id': 6,
        'totalPurchase': 99.0,
      };
      final contentFromDouble = Content.fromJson(jsonDouble);
      expect(contentFromDouble.totalPurchase, equals(99));
    });

    test('serializes totalPurchase to JSON correctly', () {
      final content = Content(
        id: 7,
        title: 'Serialization Test',
        totalPurchase: 250,
      );
      final json = content.toJson();
      expect(json['totalPurchase'], equals(250));
    });
  });
}
