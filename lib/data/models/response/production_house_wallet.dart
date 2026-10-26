double _money(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final asNum = num.tryParse(value.toString());
  if (asNum != null && asNum > 1000000000) {
    return DateTime.fromMillisecondsSinceEpoch(asNum.toInt());
  }
  return DateTime.tryParse(value.toString());
}

class ProductionHouseWalletSummary {
  const ProductionHouseWalletSummary({
    required this.walletId,
    required this.productionHouseId,
    required this.availableBalance,
    required this.totalCreditedAmount,
    required this.totalDebitedAmount,
    required this.heldAmount,
    required this.totalTransactions,
    required this.walletStatus,
    this.lastCreditDate,
    this.updatedAt,
  });

  factory ProductionHouseWalletSummary.fromJson(Map<String, dynamic> json) =>
      ProductionHouseWalletSummary(
        walletId: _integer(json['walletId']),
        productionHouseId: _integer(json['productionHouseId'] ?? json['userId']),
        availableBalance: _money(json['availableBalance'] ?? json['balance']),
        totalCreditedAmount: _money(json['totalCreditedAmount']),
        totalDebitedAmount: _money(json['totalDebitedAmount']),
        heldAmount: _money(json['heldAmount']),
        totalTransactions: _integer(json['totalTransactions']),
        walletStatus: json['walletStatus']?.toString().trim().isNotEmpty == true
            ? json['walletStatus'].toString()
            : 'ACTIVE',
        lastCreditDate: _date(json['lastCreditDate']),
        updatedAt: _date(json['updatedAt']),
      );

  final int walletId;
  final int productionHouseId;
  final double availableBalance;
  final double totalCreditedAmount;
  final double totalDebitedAmount;
  final double heldAmount;
  final int totalTransactions;
  final String walletStatus;
  final DateTime? lastCreditDate;
  final DateTime? updatedAt;

  static const empty = ProductionHouseWalletSummary(
    walletId: 0,
    productionHouseId: 0,
    availableBalance: 0,
    totalCreditedAmount: 0,
    totalDebitedAmount: 0,
    heldAmount: 0,
    totalTransactions: 0,
    walletStatus: 'ACTIVE',
  );
}

class WalletTransaction {
  const WalletTransaction({
    required this.walletTransactionId,
    required this.transactionReference,
    required this.productionHouseId,
    required this.transactionType,
    required this.entryType,
    required this.creditAmount,
    required this.debitAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.description,
    this.productionHouseName,
    this.transactionDate,
    this.settlementId,
    this.settlementReference,
    this.settlementPeriod,
    this.walletCreditDate,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final action = json['action']?.toString().toUpperCase();
    final isCreditAction = action == 'CREDIT';
    final isDebitAction =
        action == 'DEDUCT' || action == 'DEBIT' || action == 'WITHDRAW';
    final rawAmount = _money(json['amount']);
    final credit = _money(json['creditAmount'] ??
        json['creditedAmount'] ??
        (isCreditAction ? rawAmount : 0));
    final debit = _money(json['debitAmount'] ??
        (isDebitAction ? rawAmount : (action == null && _money(json['creditAmount']) == 0 ? rawAmount : 0)));
    final balance = _money(json['balance'] ?? json['balanceAfter']);
    final desc = json['description']?.toString() ??
        json['reason']?.toString() ??
        json['deductionReason']?.toString() ??
        'N/A';
    final txnType = json['transactionType']?.toString() ??
        (action != null
            ? (action == 'DEDUCT'
                ? 'WITHDRAWAL'
                : action == 'CREDIT'
                    ? 'CREDIT'
                    : action)
            : 'N/A');
    final entry = json['entryType']?.toString() ??
        (isCreditAction ? 'CREDIT' : (isDebitAction ? 'DEBIT' : 'N/A'));

    return WalletTransaction(
      walletTransactionId: _integer(
          json['walletTransactionId'] ?? json['id'] ?? json['walletId']),
      transactionReference: json['transactionReference']?.toString() ??
          (json['payoutId'] != null ? json['payoutId'].toString() : 'N/A'),
      productionHouseId: _integer(json['productionHouseId'] ?? json['userId']),
      productionHouseName:
          json['productionHouseName']?.toString() ?? json['userName']?.toString(),
      transactionDate:
          _date(json['transactionDate'] ?? json['createdAt'] ?? json['updatedAt']),
      transactionType: txnType,
      entryType: entry,
      creditAmount: credit,
      debitAmount: debit,
      balanceBefore: _money(json['balanceBefore']),
      balanceAfter: balance,
      status: json['status']?.toString() ?? 'N/A',
      description: desc,
      settlementId: json['settlementId'],
      settlementReference: json['settlementReference']?.toString(),
      settlementPeriod: json['settlementPeriod']?.toString(),
      walletCreditDate: _date(json['walletCreditDate'] ?? json['creditedAt']),
    );
  }

  final int walletTransactionId;
  final String transactionReference;
  final int productionHouseId;
  final String? productionHouseName;
  final DateTime? transactionDate;
  final String transactionType;
  final String entryType;
  final double creditAmount;
  final double debitAmount;
  final double balanceBefore;
  final double balanceAfter;
  final String status;
  final String description;
  final dynamic settlementId;
  final String? settlementReference;
  final String? settlementPeriod;
  final DateTime? walletCreditDate;

  bool get isSettlementCredit =>
      transactionType.toUpperCase() == 'SETTLEMENT_CREDIT';
}

class WalletTransactionPage {
  const WalletTransactionPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory WalletTransactionPage.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] ??
        json['transactions'] ??
        json['items'] ??
        json['records'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((item) =>
                WalletTransaction.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <WalletTransaction>[];

    final pageNum = _integer(json['page'] ?? json['number'] ?? json['pageNo']);
    final pageSize = _integer(json['size'] ?? json['pageSize']);
    final total = _integer(
        json['totalElements'] ?? json['totalRecords'] ?? json['total'] ?? list.length);
    final calculatedPages = pageSize > 0 ? (total / pageSize).ceil() : 1;
    final totalPages = _integer(json['totalPages'] ?? json['pageCount'] ?? calculatedPages);

    return WalletTransactionPage(
      content: list,
      page: pageNum,
      size: pageSize > 0 ? pageSize : 10,
      totalElements: total,
      totalPages: totalPages > 0 ? totalPages : 1,
      first: json['first'] == true || pageNum == 0,
      last: json['last'] == true || pageNum + 1 >= (totalPages > 0 ? totalPages : 1),
    );
  }

  final List<WalletTransaction> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
}

class WalletTransactionFilter {
  const WalletTransactionFilter({
    this.search,
    this.transactionType,
    this.status,
    this.entryType,
    this.fromDate,
    this.toDate,
    this.minAmount,
    this.maxAmount,
  });

  final String? search;
  final String? transactionType;
  final String? status;
  final String? entryType;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double? minAmount;
  final double? maxAmount;

  bool get isEmpty =>
      (search?.isEmpty ?? true) &&
      transactionType == null &&
      status == null &&
      entryType == null &&
      fromDate == null &&
      toDate == null &&
      minAmount == null &&
      maxAmount == null;
}

class WalletWithdrawRequest {
  const WalletWithdrawRequest({
    required this.productionHouseId,
    required this.amount,
    this.bankAccountNumber,
    this.bankIfsc,
    this.bankName,
    this.accountHolderName,
    this.currency = 'INR',
    this.remarks,
  });

  final int productionHouseId;
  final double amount;
  final String? bankAccountNumber;
  final String? bankIfsc;
  final String? bankName;
  final String? accountHolderName;
  final String currency;
  final String? remarks;

  Map<String, dynamic> toJson() => {
        'productionHouseId': productionHouseId,
        'amount': amount,
        'currency': currency,
        if (bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty)
          'bankAccountNumber': bankAccountNumber!.trim(),
        if (bankIfsc != null && bankIfsc!.trim().isNotEmpty)
          'bankIfsc': bankIfsc!.trim(),
        if (bankName != null && bankName!.trim().isNotEmpty)
          'bankName': bankName!.trim(),
        if (accountHolderName != null && accountHolderName!.trim().isNotEmpty)
          'accountHolderName': accountHolderName!.trim(),
        if (remarks != null && remarks!.trim().isNotEmpty)
          'remarks': remarks!.trim(),
      };
}

class WalletWithdrawResult {
  const WalletWithdrawResult({
    required this.withdrawalId,
    required this.transactionId,
    required this.amount,
    required this.status,
    required this.message,
    this.currency = 'INR',
    this.availableBalance,
    this.payoutId,
    this.createdAt,
  });

  factory WalletWithdrawResult.fromJson(Map<String, dynamic> json,
      {String defaultMessage = 'Withdrawal processed'}) {
    return WalletWithdrawResult(
      withdrawalId: json['withdrawalId']?.toString() ??
          json['id']?.toString() ??
          json['walletId']?.toString() ??
          'N/A',
      transactionId: json['transactionId']?.toString() ??
          json['transactionReference']?.toString() ??
          json['payoutId']?.toString() ??
          'N/A',
      amount: _money(json['amount']),
      status: json['status']?.toString() ?? 'PROCESSING',
      message: json['message']?.toString() ?? defaultMessage,
      currency: json['currency']?.toString() ?? 'INR',
      availableBalance: json['availableBalance'] != null
          ? _money(json['availableBalance'])
          : null,
      payoutId: json['payoutId']?.toString(),
      createdAt: _date(json['createdAt'] ?? json['transactionDate']),
    );
  }

  final String withdrawalId;
  final String transactionId;
  final double amount;
  final String status;
  final String message;
  final String currency;
  final double? availableBalance;
  final String? payoutId;
  final DateTime? createdAt;
}

class WalletWithdrawResponse {
  const WalletWithdrawResponse({
    required this.success,
    required this.message,
    this.statusCode = 200,
    this.data,
  });

  factory WalletWithdrawResponse.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true ||
        json['statusCode'] == 200 ||
        json['statusCode'] == 201;
    final msg = json['message']?.toString() ??
        (success
            ? 'Withdrawal request created successfully.'
            : 'Withdrawal failed.');
    final rawData = json['data'] ?? json['result'] ?? json;
    return WalletWithdrawResponse(
      success: success,
      message: msg,
      statusCode: _integer(json['statusCode'] ?? 200),
      data: rawData is Map
          ? WalletWithdrawResult.fromJson(Map<String, dynamic>.from(rawData),
              defaultMessage: msg)
          : null,
    );
  }

  final bool success;
  final String message;
  final int statusCode;
  final WalletWithdrawResult? data;
}
