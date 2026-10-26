import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/data/models/response/media_house_settlement.dart';
import 'package:media_house/data/models/response/weekly_settlement_report.dart';
import 'package:media_house/data/services/settlement_service.dart';

void main() {
  test('parses settlement page and preserves null period dates', () {
    final response = MediaHouseSettlementResponse.fromJson({
      'message': 'ok',
      'success': true,
      'statusCode': 200,
      'data': {
        'content': [
          {
            'settlementId': null,
            'mediaHouseId': 501,
            'mediaHouseName': 'ABC Productions',
            'settlementPeriod': 'Weekly',
            'periodStartDate': null,
            'periodEndDate': null,
            'settlementDate': '2026-07-09T10:30:00Z',
            'settlementStatus': 'PAID',
            'totalTransactions': 1,
            'contentType': 'MOVIE',
            'customerPayment': 100,
            'gstCharges': 15.2542,
            'customerPlatformCharges': 2,
            'netRevenue': 82.7458,
            'mediaHouseCommissionPercentage': 70,
            'mediaHouseCommission': 57.9221,
            'grossRevenue': '57.9221',
            'tds': 5.7922,
            'settlementPlatformCharges': 1.0426,
            'otherDeductions': 0,
            'totalDeductions': 6.8348,
            'finalPayableAmount': 51.0873,
          }
        ],
        'number': 0,
        'size': 10,
        'totalElements': 24,
        'totalPages': 3,
        'first': true,
        'last': false,
        'empty': false,
      }
    });

    expect(response.data.content.single.settlementId, isNull);
    expect(response.data.content.single.periodStartDate, isNull);
    expect(
        response.data.content.single.settlementStatus, SettlementStatus.paid);
    expect(response.data.content.single.contentType, ContentType.movie);
    expect(response.data.totalPages, 3);
    expect(response.data.last, isFalse);
    expect(response.data.content.single.grossRevenue, 57.9221);
  });

  test('rejects invalid settlement request parameters', () async {
    final service = SettlementService();
    expect(() => service.getMediaHouseSettlements(0),
        throwsA(isA<SettlementServiceException>()));
    expect(() => service.getMediaHouseSettlements(1, page: -1),
        throwsA(isA<SettlementServiceException>()));
    expect(() => service.getMediaHouseSettlements(1, size: 101),
        throwsA(isA<SettlementServiceException>()));
  });

  test('builds single-ott URLs and safely derives transaction batch', () {
    expect(ApiConstant.mediaHouseSettlements(2),
        '${ApiConstant.baseUrl}api/settlements/media-house/2?page=0&size=10');
    final settlement = MediaHouseSettlement.fromJson({
      'settlementId': 'WKL-SET-2026-W26-001-TXN-79',
    });
    expect(settlement.batchReference, 'WKL-SET-2026-W26-001');
  });

  test('weekly report accepts empty dynamic collections', () {
    final response = WeeklySettlementReportResponse.fromJson({
      'success': true,
      'statusCode': 200,
      'data': {
        'title': 'Weekly Settlement Report',
        'summaryCards': [],
        'sections': [],
        'beneficiarySettlementSummary': [],
        'taxAndChargeSummary': {},
        'finalSummary': [],
      },
    });
    expect(response.data.hasCalculations, isFalse);
  });

  test('weekly report parses map sections and formatted summary values', () {
    final response = WeeklySettlementReportResponse.fromJson({
      'success': true,
      'statusCode': 200,
      'data': {
        'summaryCards': [
          {
            'displayName': 'Total Customer Collection',
            'formattedValue': 'Rs. 2110.00',
          }
        ],
        'sections': {
          'Step 1: Collection breakup': {
            'calculations': {
              'baseAmount': 1788.1356,
              'gstIncluded': 321.8644,
            }
          }
        },
        'beneficiarySettlementSummary': {},
        'taxAndChargeSummary': {},
        'finalSummary': {},
      },
    });

    expect(
        response.data.summaryCards.single.label, 'Total Customer Collection');
    expect(response.data.summaryCards.single.value, 'Rs. 2110.00');
    expect(response.data.sections.single.title, 'Step 1: Collection breakup');
    expect(response.data.sections.single.entries, hasLength(2));
    expect(response.data.sections.single.entries.first.label, 'baseAmount');
    expect(response.data.sections.single.entries.first.value, 1788.1356);
  });
}
