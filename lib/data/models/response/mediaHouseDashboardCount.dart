class MediaHouseDashboardCount {
  MediaHouseDashboardData? data;
  String? message;
  int? statusCode;
  bool? isSuccess;

  MediaHouseDashboardCount({
    this.data,
    this.message,
    this.statusCode,
    this.isSuccess,
  });

  factory MediaHouseDashboardCount.fromJson(Map<String, dynamic> json) =>
      MediaHouseDashboardCount(
        data: json["data"] == null
            ? null
            : MediaHouseDashboardData.fromJson(json["data"]),
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        isSuccess: json["isSuccess"] == true ||
            json["success"] == true ||
            json["statusCode"] == 200,
      );

  Map<String, dynamic> toJson() => {
        "data": data?.toJson(),
        "message": message,
        "statusCode": statusCode,
        "isSuccess": isSuccess,
      };
}

class MediaHouseDashboardData {
  // v2 Fields
  int? liveContent;
  double? walletAmount;
  int? upcomingContent;
  int? pendingContent;
  int? totalViews;
  String? productionHouseName;
  int? purchaseCount;
  double? customerPayment;
  double? gstCharges;
  double? baseAmountAfterGST;
  double? paymentGatewayFees;
  double? netRevenue;
  double? platformRevenue;
  double? productionHouseRevenue;
  double? tax;
  double? paymentGatewayFee;
  double? finalProductionHouseRevenue;
  double? promoterRevenue;
  int? totalContentCount;

  // Legacy compatibility fields
  int? rejectedContentCount;

  MediaHouseDashboardData({
    this.liveContent,
    this.walletAmount,
    this.upcomingContent,
    this.pendingContent,
    this.totalViews,
    this.productionHouseName,
    this.purchaseCount,
    this.customerPayment,
    this.gstCharges,
    this.baseAmountAfterGST,
    this.paymentGatewayFees,
    this.netRevenue,
    this.platformRevenue,
    this.productionHouseRevenue,
    this.tax,
    this.paymentGatewayFee,
    this.finalProductionHouseRevenue,
    this.promoterRevenue,
    this.totalContentCount,
    this.rejectedContentCount,
  });

  // Backward compatibility getters
  int? get approvedContent => liveContent;
  int? get upcomingContentCount => upcomingContent;
  int? get pendingContentCount => pendingContent;
  double? get viewRevenue => finalProductionHouseRevenue ?? productionHouseRevenue ?? netRevenue;
  double? get mediaHouseNetRevenue => finalProductionHouseRevenue ?? productionHouseRevenue ?? netRevenue;
  double? get mediaHouseGrossRevenue => customerPayment ?? baseAmountAfterGST;

  factory MediaHouseDashboardData.fromJson(Map<String, dynamic> json) =>
      MediaHouseDashboardData(
        liveContent: _readNullableInt(json["Live Content"] ?? json["liveContent"] ?? json["Approved Content"]),
        walletAmount: _readNullableDouble(json["Wallet Amount"] ?? json["walletAmount"]),
        upcomingContent: _readNullableInt(json["Upcoming Content"] ?? json["upcomingContent"] ?? json["Upcoming Content Count"]),
        pendingContent: _readNullableInt(json["Pending Content"] ?? json["pendingContent"] ?? json["Pending Content Count"]),
        totalViews: _readNullableInt(json["Total Views"] ?? json["totalViews"]),
        productionHouseName: json["Production House Name"]?.toString() ?? json["productionHouseName"]?.toString(),
        purchaseCount: _readNullableInt(json["Purchase Count"] ?? json["purchaseCount"]),
        customerPayment: _readNullableDouble(json["Customer Payment"] ?? json["customerPayment"] ?? json["mediaHouseGrossRevenue"]),
        gstCharges: _readNullableDouble(json["GST Charges"] ?? json["gstCharges"] ?? json["gstAmount"]),
        baseAmountAfterGST: _readNullableDouble(json["Base Amount After GST"] ?? json["baseAmountAfterGST"] ?? json["baseAmount"]),
        paymentGatewayFees: _readNullableDouble(json["Payment Gateway Fees"] ?? json["paymentGatewayFees"] ?? json["gatewayFee"]),
        netRevenue: _readNullableDouble(json["Net Revenue"] ?? json["netRevenue"] ?? json["mediaHouseNetRevenue"] ?? json["viewRevenue"]),
        platformRevenue: _readNullableDouble(json["Platform Revenue"] ?? json["platformRevenue"] ?? json["adminRevenueShare"]),
        productionHouseRevenue: _readNullableDouble(json["Production House Revenue"] ?? json["productionHouseRevenue"] ?? json["mediaHouseRevenueShare"] ?? json["mediaHouseGrossRevenue"]),
        tax: _readNullableDouble(json["tax"] ?? json["Tax"]),
        paymentGatewayFee: _readNullableDouble(json["Payment Gateway Fee"] ?? json["paymentGatewayFee"]),
        finalProductionHouseRevenue: _readNullableDouble(
          json["Final Production House Revenue"] ?? json["finalProductionHouseRevenue"] ?? json["Production House Revenue"] ?? json["productionHouseRevenue"] ?? json["mediaHouseNetRevenue"] ?? json["viewRevenue"],
        ),
        promoterRevenue: _readNullableDouble(json["promoterRevenue"] ?? json["Promoter Revenue"]),
        totalContentCount: _readNullableInt(json["totalContentCount"] ?? json["Total Content Count"] ?? json["liveContent"] ?? json["Live Content"]),
        rejectedContentCount: _readNullableInt(json["Rejected Content Count"] ?? json["rejectedContentCount"]),
      );

  Map<String, dynamic> toJson() => {
        "liveContent": liveContent,
        "walletAmount": walletAmount,
        "upcomingContent": upcomingContent,
        "pendingContent": pendingContent,
        "totalViews": totalViews,
        "Production House Name": productionHouseName,
        "purchaseCount": purchaseCount,
        "customerPayment": customerPayment,
        "gstCharges": gstCharges,
        "baseAmountAfterGST": baseAmountAfterGST,
        "paymentGatewayFees": paymentGatewayFees,
        "netRevenue": netRevenue,
        "platformRevenue": platformRevenue,
        "productionHouseRevenue": productionHouseRevenue,
        "tax": tax,
        "paymentGatewayFee": paymentGatewayFee,
        "finalProductionHouseRevenue": finalProductionHouseRevenue,
        "promoterRevenue": promoterRevenue,
        "totalContentCount": totalContentCount,
        "Approved Content": approvedContent,
        "Upcoming Content Count": upcomingContent,
        "Pending Content Count": pendingContent,
        "Rejected Content Count": rejectedContentCount,
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
