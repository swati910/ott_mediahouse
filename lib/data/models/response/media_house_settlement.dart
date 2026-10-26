enum SettlementStatus {
  paid,
  completed,
  pending,
  processing,
  failed,
  rejected,
  cancelled,
  unknown
}

enum ContentType { movie, shortFilm, series, shorts, unknown }

SettlementStatus settlementStatusFrom(String? value) {
  return SettlementStatus.values.firstWhere(
    (item) => item.name == value?.trim().toLowerCase(),
    orElse: () => SettlementStatus.unknown,
  );
}

ContentType contentTypeFrom(String? value) {
  if (value?.trim().toUpperCase() == 'SHORT_FILM') {
    return ContentType.shortFilm;
  }
  return ContentType.values.firstWhere(
    (item) => item.name == value?.trim().toLowerCase(),
    orElse: () => ContentType.unknown,
  );
}

class MediaHouseSettlement {
  final String? settlementId;
  final String? settlementBatchReference;
  final int mediaHouseId;
  final String mediaHouseName;
  final String settlementPeriod;
  final DateTime? periodStartDate;
  final DateTime? periodEndDate;
  final DateTime? settlementDate;
  final SettlementStatus settlementStatus;
  final String settlementStatusValue;
  final int totalTransactions;
  final ContentType contentType;
  final String contentTypeValue;
  final double customerPayment;
  final double gstCharges;
  final double customerPlatformCharges;
  final double netRevenue;
  final double mediaHouseCommissionPercentage;
  final double mediaHouseCommission;
  final double grossRevenue;
  final double tds;
  final double settlementPlatformCharges;
  final double otherDeductions;
  final double totalDeductions;
  final double finalPayableAmount;
  final bool walletCredited;
  final DateTime? walletCreditedAt;
  final String? walletTransactionReference;
  final double walletCreditedAmount;

  const MediaHouseSettlement({
    required this.settlementId,
    required this.settlementBatchReference,
    required this.mediaHouseId,
    required this.mediaHouseName,
    required this.settlementPeriod,
    required this.periodStartDate,
    required this.periodEndDate,
    required this.settlementDate,
    required this.settlementStatus,
    required this.settlementStatusValue,
    required this.totalTransactions,
    required this.contentType,
    required this.contentTypeValue,
    required this.customerPayment,
    required this.gstCharges,
    required this.customerPlatformCharges,
    required this.netRevenue,
    required this.mediaHouseCommissionPercentage,
    required this.mediaHouseCommission,
    required this.grossRevenue,
    required this.tds,
    required this.settlementPlatformCharges,
    required this.otherDeductions,
    required this.totalDeductions,
    required this.finalPayableAmount,
    this.walletCredited = false,
    this.walletCreditedAt,
    this.walletTransactionReference,
    this.walletCreditedAmount = 0,
  });

  factory MediaHouseSettlement.fromJson(Map<String, dynamic> json) {
    final status = json['settlementStatus']?.toString().trim() ?? 'UNKNOWN';
    final type = json['contentType']?.toString().trim() ?? 'UNKNOWN';
    return MediaHouseSettlement(
      settlementId: _nullableText(json['settlementId']),
      settlementBatchReference: _nullableText(json['settlementBatchReference']),
      mediaHouseId: _int(json['mediaHouseId']),
      mediaHouseName: json['mediaHouseName']?.toString() ?? '',
      settlementPeriod: json['settlementPeriod']?.toString() ?? '',
      periodStartDate: _date(json['periodStartDate']),
      periodEndDate: _date(json['periodEndDate']),
      settlementDate: _date(json['settlementDate']),
      settlementStatus: settlementStatusFrom(status),
      settlementStatusValue: status.isEmpty ? 'UNKNOWN' : status,
      totalTransactions: _int(json['totalTransactions']),
      contentType: contentTypeFrom(type),
      contentTypeValue: type.isEmpty ? 'UNKNOWN' : type,
      customerPayment: _double(json['customerPayment']),
      gstCharges: _double(json['gstCharges']),
      customerPlatformCharges: _double(json['customerPlatformCharges']),
      netRevenue: _double(json['netRevenue']),
      mediaHouseCommissionPercentage:
          _double(json['mediaHouseCommissionPercentage']),
      mediaHouseCommission: _double(json['mediaHouseCommission']),
      grossRevenue: _double(json['grossRevenue']),
      tds: _double(json['tds']),
      settlementPlatformCharges: _double(json['settlementPlatformCharges']),
      otherDeductions: _double(json['otherDeductions']),
      totalDeductions: _double(json['totalDeductions']),
      finalPayableAmount: _double(json['finalPayableAmount']),
      walletCredited: json['walletCredited'] == true,
      walletCreditedAt:
          _date(json['walletCreditedAt'] ?? json['walletCreditDate']),
      walletTransactionReference: _nullableText(
        json['walletTransactionReference'] ??
            json['walletTransactionId'] ??
            json['transactionReference'],
      ),
      walletCreditedAmount: _double(
        json['walletCreditedAmount'] ??
            json['creditedAmount'] ??
            json['finalPayableAmount'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'settlementId': settlementId,
        'settlementBatchReference': settlementBatchReference,
        'mediaHouseId': mediaHouseId,
        'mediaHouseName': mediaHouseName,
        'settlementPeriod': settlementPeriod,
        'periodStartDate': periodStartDate?.toUtc().toIso8601String(),
        'periodEndDate': periodEndDate?.toUtc().toIso8601String(),
        'settlementDate': settlementDate?.toUtc().toIso8601String(),
        'settlementStatus': settlementStatusValue,
        'totalTransactions': totalTransactions,
        'contentType': contentTypeValue,
        'customerPayment': customerPayment,
        'gstCharges': gstCharges,
        'customerPlatformCharges': customerPlatformCharges,
        'netRevenue': netRevenue,
        'mediaHouseCommissionPercentage': mediaHouseCommissionPercentage,
        'mediaHouseCommission': mediaHouseCommission,
        'grossRevenue': grossRevenue,
        'tds': tds,
        'settlementPlatformCharges': settlementPlatformCharges,
        'otherDeductions': otherDeductions,
        'totalDeductions': totalDeductions,
        'finalPayableAmount': finalPayableAmount,
        'walletCredited': walletCredited,
        'walletCreditedAt': walletCreditedAt?.toUtc().toIso8601String(),
        'walletTransactionReference': walletTransactionReference,
        'walletCreditedAmount': walletCreditedAmount,
      };

  String? get batchReference {
    final dedicated = settlementBatchReference?.trim();
    if (dedicated != null && dedicated.isNotEmpty) return dedicated;
    final id = settlementId?.trim();
    if (id == null || id.isEmpty) return null;
    return id.replaceFirst(RegExp(r'-TXN-\d+$', caseSensitive: false), '');
  }

  String get contentTypeLabel => switch (contentType) {
        ContentType.movie => 'Movie',
        ContentType.shortFilm => 'Short Film',
        ContentType.series => 'Series',
        ContentType.shorts => 'Mini Series',
        ContentType.unknown => contentTypeValue,
      };
}

class SettlementPageData {
  final List<MediaHouseSettlement> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;
  final bool empty;

  const SettlementPageData({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
    required this.empty,
  });

  factory SettlementPageData.fromJson(Map<String, dynamic> json) {
    final raw = json['content'];
    final content = raw is List
        ? raw
            .whereType<Map>()
            .map((item) =>
                MediaHouseSettlement.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : <MediaHouseSettlement>[];
    return SettlementPageData(
      content: content,
      number: _int(json['number']),
      size: _int(json['size']),
      totalElements: _int(json['totalElements']),
      totalPages: _int(json['totalPages']),
      first: json['first'] == true,
      last: json['last'] == true,
      empty: json['empty'] == true || content.isEmpty,
    );
  }

  Map<String, dynamic> toJson() => {
        'content': content.map((item) => item.toJson()).toList(),
        'number': number,
        'size': size,
        'totalElements': totalElements,
        'totalPages': totalPages,
        'first': first,
        'last': last,
        'empty': empty,
      };
}

class MediaHouseSettlementResponse {
  final String message;
  final bool success;
  final SettlementPageData data;
  final int statusCode;

  const MediaHouseSettlementResponse({
    required this.message,
    required this.success,
    required this.data,
    required this.statusCode,
  });

  factory MediaHouseSettlementResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('Settlement response data is missing.');
    }
    return MediaHouseSettlementResponse(
      message: json['message']?.toString() ?? '',
      success: json['success'] == true,
      data: SettlementPageData.fromJson(Map<String, dynamic>.from(rawData)),
      statusCode: _int(json['statusCode']),
    );
  }
}

String? _nullableText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : DateTime.tryParse(text);
}

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double _double(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
