class MovieTransactionResponse {
  final String? message;
  final List<MovieTransaction> data;
  final int? statusCode;
  final bool success;

  MovieTransactionResponse({
    this.message,
    this.data = const [],
    this.statusCode,
    this.success = false,
  });

  factory MovieTransactionResponse.fromJson(Map<String, dynamic> json) {
    var rawList = json['data'];
    List<MovieTransaction> items = [];
    if (rawList is List) {
      items = rawList
          .whereType<Map<String, dynamic>>()
          .map(MovieTransaction.fromJson)
          .toList();
    }
    return MovieTransactionResponse(
      message: json['message']?.toString(),
      data: items,
      statusCode: json['statusCode'] is int
          ? json['statusCode']
          : int.tryParse(json['statusCode']?.toString() ?? ''),
      success: json['success'] == true ||
          json['isSuccess'] == true ||
          json['statusCode'] == 200,
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'data': data.map((e) => e.toJson()).toList(),
        'statusCode': statusCode,
        'success': success,
      };
}

class MovieTransaction {
  final String? transactionId;
  final int? movieId;
  final String? movieTitle;
  final int? dateFrom;
  final int? dateTo;
  final String? status;
  final double? customerPayment;
  final double? baseAmount;
  final double? gstAmount;
  final double? gatewayFee;
  final double? netRevenue;
  final double? mediaHouseRevenueShare;
  final double? adminRevenueShare;

  MovieTransaction({
    this.transactionId,
    this.movieId,
    this.movieTitle,
    this.dateFrom,
    this.dateTo,
    this.status,
    this.customerPayment,
    this.baseAmount,
    this.gstAmount,
    this.gatewayFee,
    this.netRevenue,
    this.mediaHouseRevenueShare,
    this.adminRevenueShare,
  });

  DateTime? get fromDateTime =>
      dateFrom != null ? DateTime.fromMillisecondsSinceEpoch(dateFrom!) : null;

  DateTime? get toDateTime =>
      dateTo != null ? DateTime.fromMillisecondsSinceEpoch(dateTo!) : null;

  factory MovieTransaction.fromJson(Map<String, dynamic> json) =>
      MovieTransaction(
        transactionId: json['transactionId']?.toString(),
        movieId: _readNullableInt(json['movieId']),
        movieTitle: json['movieTitle']?.toString(),
        dateFrom: _readNullableInt(json['dateFrom']),
        dateTo: _readNullableInt(json['dateTo']),
        status: json['status']?.toString(),
        customerPayment: _readNullableDouble(json['customerPayment']),
        baseAmount: _readNullableDouble(json['baseAmount']),
        gstAmount: _readNullableDouble(json['gstAmount']),
        gatewayFee: _readNullableDouble(json['gatewayFee']),
        netRevenue: _readNullableDouble(json['netRevenue']),
        mediaHouseRevenueShare:
            _readNullableDouble(json['mediaHouseRevenueShare']),
        adminRevenueShare: _readNullableDouble(json['adminRevenueShare']),
      );

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'movieId': movieId,
        'movieTitle': movieTitle,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'status': status,
        'customerPayment': customerPayment,
        'baseAmount': baseAmount,
        'gstAmount': gstAmount,
        'gatewayFee': gatewayFee,
        'netRevenue': netRevenue,
        'mediaHouseRevenueShare': mediaHouseRevenueShare,
        'adminRevenueShare': adminRevenueShare,
      };
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _readNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
