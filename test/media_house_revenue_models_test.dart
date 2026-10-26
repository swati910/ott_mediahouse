import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/data/models/response/mediaHouseDashboardCount.dart';
import 'package:media_house/data/models/response/topRevenueMovie.dart';
import 'package:media_house/domain/entities/content.dart';

void main() {
  group('media-house revenue fields', () {
    test('content parses gross and net revenue and prefers net for display', () {
      final content = Content.fromJson({
        'totalRevenue': 5,
        'mediaHouseRevenue': 2.5544,
        'mediaHouseGrossRevenue': 2.8961,
        'mediaHouseNetRevenue': 2.5544,
      });

      expect(content.mediaHouseGrossRevenue, 2.8961);
      expect(content.mediaHouseNetRevenue, 2.5544);
      expect(content.effectiveMediaHouseNetRevenue, 2.5544);
    });

    test('content falls back to legacy mediaHouseRevenue', () {
      final content = Content.fromJson({'mediaHouseRevenue': '2.5544'});

      expect(content.effectiveMediaHouseGrossRevenue, 2.5544);
      expect(content.effectiveMediaHouseNetRevenue, 2.5544);
    });

    test('dashboard parses new fields with legacy net fallback', () {
      final current = MediaHouseDashboardData.fromJson({
        'viewRevenue': 2.5544,
        'mediaHouseGrossRevenue': 2.8961,
        'mediaHouseNetRevenue': 2.5544,
      });
      final legacy =
          MediaHouseDashboardData.fromJson({'viewRevenue': 2.5544});

      expect(current.mediaHouseGrossRevenue, 2.8961);
      expect(current.mediaHouseNetRevenue, 2.5544);
      expect(legacy.mediaHouseNetRevenue, 2.5544);
    });

    test('top revenue content uses new net value and parses wrapper total', () {
      final response = TopRevenueMovie.fromJson({
        'success': true,
        'data': {
          'totalRevenue': 2.5544,
          'contentWithRevenue': [
            {
              'Name': 'Sample',
              'totalRevenue': 2.5544,
              'mediaHouseGrossRevenue': 2.8961,
              'mediaHouseNetRevenue': 2.5544,
            },
          ],
        },
      });

      final item = response.data!.contentWithRevenue!.single;
      expect(item.mediaHouseGrossRevenue, 2.8961);
      expect(item.mediaHouseNetRevenue, 2.5544);
      expect(response.data!.totalRevenue, 2.5544);
    });
  });
}
