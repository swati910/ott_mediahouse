class TransactionSettlementAuditResponse {
  bool? success;
  String? message;
  int? statusCode;
  TransactionSettlementAuditData? data;

  TransactionSettlementAuditResponse({
    this.success,
    this.message,
    this.statusCode,
    this.data,
  });

  factory TransactionSettlementAuditResponse.fromJson(Map<String, dynamic> json) =>
      TransactionSettlementAuditResponse(
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        data: json["data"] != null
            ? TransactionSettlementAuditData.fromJson(
                json["data"] is Map ? Map<String, dynamic>.from(json["data"]) : {})
            : null,
      );

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "statusCode": statusCode,
        "data": data?.toJson(),
      };
}

class TransactionSettlementAuditData {
  String? transactionId;
  String? settlementId;
  String? movieName;
  String? customerName;
  String? customerEmail;
  String? customerPhone;
  String? paymentDate;
  String? settlementDate;
  String? paymentGateway;
  String? gatewayTransactionId;
  String? utrNumber;
  String? status;

  double? grossAmount;
  double? gstAmount;
  double? baseAmount;
  double? gatewayFee;
  double? netRevenue;
  double? platformShare;
  double? mediaHouseShare;
  double? tdsAmount;
  double? payoutFee;
  double? finalDisbursedAmount;

  TransactionSettlementAuditData({
    this.transactionId,
    this.settlementId,
    this.movieName,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.paymentDate,
    this.settlementDate,
    this.paymentGateway,
    this.gatewayTransactionId,
    this.utrNumber,
    this.status,
    this.grossAmount,
    this.gstAmount,
    this.baseAmount,
    this.gatewayFee,
    this.netRevenue,
    this.platformShare,
    this.mediaHouseShare,
    this.tdsAmount,
    this.payoutFee,
    this.finalDisbursedAmount,
  });

  factory TransactionSettlementAuditData.fromJson(Map<String, dynamic> json) =>
      TransactionSettlementAuditData(
        transactionId: json["transactionId"]?.toString() ?? json["txnId"]?.toString(),
        settlementId: json["settlementId"]?.toString() ?? json["batchReference"]?.toString(),
        movieName: json["movieName"]?.toString() ?? json["contentName"]?.toString(),
        customerName: json["customerName"]?.toString() ?? json["userName"]?.toString(),
        customerEmail: json["customerEmail"]?.toString() ?? json["email"]?.toString(),
        customerPhone: json["customerPhone"]?.toString() ?? json["mobileNumber"]?.toString(),
        paymentDate: json["paymentDate"]?.toString() ?? json["createdAt"]?.toString(),
        settlementDate: json["settlementDate"]?.toString() ?? json["disbursedDate"]?.toString(),
        paymentGateway: json["paymentGateway"]?.toString() ?? "Razorpay",
        gatewayTransactionId: json["gatewayTransactionId"]?.toString() ?? json["orderId"]?.toString(),
        utrNumber: json["utrNumber"]?.toString() ?? json["utr"]?.toString(),
        status: json["status"]?.toString() ?? "PAID",
        grossAmount: _readDouble(json["grossAmount"] ?? json["customerPayment"] ?? json["amount"]),
        gstAmount: _readDouble(json["gstAmount"] ?? json["gst"]),
        baseAmount: _readDouble(json["baseAmount"] ?? json["baseAmountAfterGST"]),
        gatewayFee: _readDouble(json["gatewayFee"] ?? json["paymentGatewayFees"]),
        netRevenue: _readDouble(json["netRevenue"]),
        platformShare: _readDouble(json["platformShare"] ?? json["platformRevenue"]),
        mediaHouseShare: _readDouble(json["mediaHouseShare"] ?? json["productionHouseRevenue"]),
        tdsAmount: _readDouble(json["tdsAmount"] ?? json["tds"]),
        payoutFee: _readDouble(json["payoutFee"]),
        finalDisbursedAmount: _readDouble(json["finalDisbursedAmount"] ?? json["finalProductionHouseRevenue"]),
      );

  Map<String, dynamic> toJson() => {
        "transactionId": transactionId,
        "settlementId": settlementId,
        "movieName": movieName,
        "customerName": customerName,
        "customerEmail": customerEmail,
        "customerPhone": customerPhone,
        "paymentDate": paymentDate,
        "settlementDate": settlementDate,
        "paymentGateway": paymentGateway,
        "gatewayTransactionId": gatewayTransactionId,
        "utrNumber": utrNumber,
        "status": status,
        "grossAmount": grossAmount,
        "gstAmount": gstAmount,
        "baseAmount": baseAmount,
        "gatewayFee": gatewayFee,
        "netRevenue": netRevenue,
        "platformShare": platformShare,
        "mediaHouseShare": mediaHouseShare,
        "tdsAmount": tdsAmount,
        "payoutFee": payoutFee,
        "finalDisbursedAmount": finalDisbursedAmount,
      };
}

double? _readDouble(dynamic val) {
  if (val == null) return null;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString());
}
