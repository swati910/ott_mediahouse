class ContentRevenueBreakdownResponse {
  bool? success;
  String? message;
  int? statusCode;
  ContentRevenueBreakdownData? data;

  ContentRevenueBreakdownResponse({
    this.success,
    this.message,
    this.statusCode,
    this.data,
  });

  factory ContentRevenueBreakdownResponse.fromJson(Map<String, dynamic> json) =>
      ContentRevenueBreakdownResponse(
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        data: json["data"] != null
            ? ContentRevenueBreakdownData.fromJson(
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

class ContentRevenueBreakdownData {
  int? contentId;
  String? contentName;
  String? contentType;
  int? totalPurchases;
  int? totalViews;

  // Financial Breakdown Fields
  double? customerPayment;
  double? gst;
  double? gatewayFee;
  double? netRevenue;
  double? productionGross;
  double? tds;
  double? payoutFee;
  double? finalNetRevenue;
  double? platformRevenue;
  double? promoterRevenue;

  ContentRevenueBreakdownData({
    this.contentId,
    this.contentName,
    this.contentType,
    this.totalPurchases,
    this.totalViews,
    this.customerPayment,
    this.gst,
    this.gatewayFee,
    this.netRevenue,
    this.productionGross,
    this.tds,
    this.payoutFee,
    this.finalNetRevenue,
    this.platformRevenue,
    this.promoterRevenue,
  });

  factory ContentRevenueBreakdownData.fromJson(Map<String, dynamic> json) =>
      ContentRevenueBreakdownData(
        contentId: _readInt(json["contentId"] ?? json["id"]),
        contentName: json["contentName"]?.toString() ?? json["name"]?.toString(),
        contentType: json["contentType"]?.toString() ?? json["type"]?.toString(),
        totalPurchases: _readInt(json["totalPurchases"] ?? json["purchaseCount"]),
        totalViews: _readInt(json["totalViews"] ?? json["views"]),
        customerPayment: _readDouble(json["customerPayment"] ??
            json["Customer Payment"] ??
            json["grossRevenue"] ??
            json["totalRevenue"]),
        gst: _readDouble(json["gst"] ?? json["GST"] ?? json["gstCharges"] ?? json["gstAmount"]),
        gatewayFee: _readDouble(json["gatewayFee"] ??
            json["Gateway Fee"] ??
            json["paymentGatewayFees"] ??
            json["paymentGatewayFee"]),
        netRevenue: _readDouble(json["netRevenue"] ?? json["Net Revenue"]),
        productionGross: _readDouble(json["productionGross"] ??
            json["Production Gross"] ??
            json["productionHouseRevenue"] ??
            json["mediaHouseGrossRevenue"]),
        tds: _readDouble(json["tds"] ?? json["TDS"] ?? json["tax"]),
        payoutFee: _readDouble(json["payoutFee"] ?? json["Payout Fee"] ?? json["payoutCharges"]),
        finalNetRevenue: _readDouble(json["finalNetRevenue"] ??
            json["Final Net Revenue"] ??
            json["finalProductionHouseRevenue"] ??
            json["mediaHouseNetRevenue"]),
        platformRevenue: _readDouble(json["platformRevenue"] ?? json["Platform Revenue"]),
        promoterRevenue: _readDouble(json["promoterRevenue"] ?? json["Promoter Revenue"]),
      );

  Map<String, dynamic> toJson() => {
        "contentId": contentId,
        "contentName": contentName,
        "contentType": contentType,
        "totalPurchases": totalPurchases,
        "totalViews": totalViews,
        "customerPayment": customerPayment,
        "gst": gst,
        "gatewayFee": gatewayFee,
        "netRevenue": netRevenue,
        "productionGross": productionGross,
        "tds": tds,
        "payoutFee": payoutFee,
        "finalNetRevenue": finalNetRevenue,
        "platformRevenue": platformRevenue,
        "promoterRevenue": promoterRevenue,
      };
}

int? _readInt(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString());
}

double? _readDouble(dynamic val) {
  if (val == null) return null;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString());
}
