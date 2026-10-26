import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/ui/pages/wallet_page/wallet_page.dart';
import 'package:media_house/data/models/response/production_house_wallet.dart';

void main() {
  test('wallet screen is available as a separate page', () {
    expect(const WalletPage(), isA<WalletPage>());
  });

  test('wallet summary parses null-safe monetary values and balance alias', () {
    final summary = ProductionHouseWalletSummary.fromJson({
      'walletId': 10,
      'productionHouseId': 501,
      'balance': 20.3,
      'totalCreditedAmount': 125000,
      'totalDebitedAmount': null,
      'heldAmount': 0,
      'totalTransactions': 8,
      'walletStatus': 'ACTIVE',
      'lastCreditDate': '2026-07-30T10:30:00Z',
    });

    expect(summary.availableBalance, 20.3);
    expect(summary.totalCreditedAmount, 125000);
    expect(summary.totalDebitedAmount, 0);
    expect(summary.lastCreditDate, isNotNull);
  });

  test('wallet transaction page keeps credit and debit separate', () {
    final page = WalletTransactionPage.fromJson({
      'content': [
        {
          'walletTransactionId': 501,
          'transactionReference': 'WAL-TXN-2026-000501',
          'transactionType': 'SETTLEMENT_CREDIT',
          'entryType': 'CREDIT',
          'creditAmount': 25000,
          'debitAmount': 0,
          'balanceAfter': 75000,
          'status': 'COMPLETED',
        }
      ],
      'page': 0,
      'size': 10,
      'totalElements': 1,
      'totalPages': 1,
      'first': true,
      'last': true,
    });

    expect(page.content.single.creditAmount, 25000);
    expect(page.content.single.debitAmount, 0);
    expect(page.content.single.isSettlementCredit, isTrue);
  });

  test('wallet transaction parses action-based history format with epoch milliseconds', () {
    final txn = WalletTransaction.fromJson({
      'creditedAmount': 69.3,
      'walletId': 1,
      'reason': 'Wallet recharge through Apple In-App Purchase.',
      'amount': 69.3,
      'movieStartDate': null,
      'movieEndDate': null,
      'transactionDate': 1786598815000,
      'userName': '',
      'userId': 1,
      'operatingSystem': 'IOS',
      'deductionReason': 'iOS payment gateway charges',
      'deductionAmount': 29.7,
      'action': 'CREDIT',
      'requestedAmount': 99,
      'deductionPercentage': 30,
      'status': 'Amount credited'
    });

    expect(txn.creditAmount, 69.3);
    expect(txn.debitAmount, 0);
    expect(txn.entryType, 'CREDIT');
    expect(txn.status, 'Amount credited');
    expect(txn.transactionDate?.millisecondsSinceEpoch, 1786598815000);
  });

  test('wallet transaction parses deduct action correctly', () {
    final txn = WalletTransaction.fromJson({
      'creditedAmount': null,
      'walletId': 1,
      'reason': 'Deducted from wallet for The March movie.',
      'amount': 49,
      'movieStartDate': 1786727341000,
      'movieEndDate': 1787332141000,
      'transactionDate': 1786727341000,
      'userName': 'null null',
      'userId': 1,
      'operatingSystem': null,
      'deductionReason': null,
      'deductionAmount': null,
      'action': 'DEDUCT',
      'requestedAmount': null,
      'deductionPercentage': null,
      'status': 'Amount deducted'
    });

    expect(txn.creditAmount, 0);
    expect(txn.debitAmount, 49);
    expect(txn.entryType, 'DEBIT');
    expect(txn.status, 'Amount deducted');
    expect(txn.description, 'Deducted from wallet for The March movie.');
  });

  test('wallet withdraw request serialization', () {
    const request = WalletWithdrawRequest(
      productionHouseId: 1,
      amount: 5000.0,
      currency: 'INR',
      bankAccountNumber: '1234567890',
      bankIfsc: 'HDFC0001234',
      bankName: 'HDFC Bank',
      accountHolderName: 'ABC Media House',
      remarks: 'Wallet withdrawal',
    );

    final json = request.toJson();
    expect(json['productionHouseId'], 1);
    expect(json['amount'], 5000.0);
    expect(json['bankAccountNumber'], '1234567890');
    expect(json['bankIfsc'], 'HDFC0001234');
    expect(json['bankName'], 'HDFC Bank');
    expect(json['accountHolderName'], 'ABC Media House');
  });

  test('wallet withdraw response parsing', () {
    final response = WalletWithdrawResponse.fromJson({
      'message': 'Withdrawal request submitted successfully',
      'data': {
        'withdrawalId': 'WTH1001',
        'transactionId': 'TXN_WTH_1786727341',
        'productionHouseId': 1,
        'amount': 5000.0,
        'currency': 'INR',
        'status': 'PROCESSING',
        'availableBalance': 15000.0,
        'payoutId': 'pout_12345',
        'createdAt': 1786727341000
      },
      'statusCode': 200,
      'success': true
    });

    expect(response.success, isTrue);
    expect(response.data?.withdrawalId, 'WTH1001');
    expect(response.data?.transactionId, 'TXN_WTH_1786727341');
    expect(response.data?.amount, 5000.0);
    expect(response.data?.status, 'PROCESSING');
    expect(response.data?.availableBalance, 15000.0);
  });

  test('wallet transaction URL uses pagination and encoded filters', () {
    final url = ApiConstant.productionHouseWalletTransactions(
      501,
      page: 2,
      size: 20,
      search: 'WAL TXN',
      transactionType: 'SETTLEMENT_CREDIT',
      entryType: 'CREDIT',
      minAmount: 1000,
    );

    expect(url, contains('/api/production-house-wallet/501/transactions?'));
    expect(url, contains('page=2'));
    expect(url, contains('size=20'));
    expect(Uri.parse(url).queryParameters['search'], 'WAL TXN');
    expect(url, contains('transactionType=SETTLEMENT_CREDIT'));
    expect(url, isNot(contains('/ott/ott/')));
  });

  test('wallet withdraw endpoints in ApiConstant', () {
    expect(ApiConstant.withdrawWalletAmount, contains('ott/wallet/withdraw'));
    expect(ApiConstant.walletHistory(1), contains('ott/wallet/history/1'));
  });
}
