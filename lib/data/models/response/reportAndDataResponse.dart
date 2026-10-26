class ReportAndDataResponse {
  String? message;
  Data? data;
  int? statusCode;
  dynamic total;
  bool? success;

  ReportAndDataResponse({
    this.message,
    this.data,
    this.statusCode,
    this.total,
    this.success,
  });

  factory ReportAndDataResponse.fromJson(Map<String, dynamic> json) =>
      ReportAndDataResponse(
        message: json["message"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        statusCode: json["statusCode"],
        total: json["total"],
        success: json["success"],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
        "statusCode": statusCode,
        "total": total,
        "success": success,
      };
}

class Data {
  String? mediaHouse;
  List<ReportAndDataObject>? contents;

  Data({
    this.mediaHouse,
    this.contents,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        mediaHouse: json["mediaHouse"],
        contents: json["contents"] == null
            ? []
            : List<ReportAndDataObject>.from(
                json["contents"]!.map((x) => ReportAndDataObject.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "mediaHouse": mediaHouse,
        "contents": contents == null
            ? []
            : List<dynamic>.from(contents!.map((x) => x.toJson())),
      };
}

class ReportAndDataObject {
  DateTime? releasedDate;
  double? price;
  double? revenue;
  double? netRevenue;
  String? movieName;
  int? views;

  ReportAndDataObject({
    this.releasedDate,
    this.price,
    this.revenue,
    this.netRevenue,
    this.movieName,
    this.views,
  });

  factory ReportAndDataObject.fromJson(Map<String, dynamic> json) =>
      ReportAndDataObject(
        releasedDate: json["releasedDate"] == null
            ? null
            : DateTime.tryParse(json["releasedDate"].toString()),
        price: _toDouble(json["price"]),
        revenue: _toDouble(json["revenue"]),
        netRevenue: _toDouble(json["netRevenue"]),
        movieName: json["movieName"],
        views: json["views"] is int
            ? json["views"]
            : int.tryParse(json["views"]?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        "releasedDate":
            releasedDate == null ? null : "${releasedDate!.year.toString().padLeft(4, '0')}-${releasedDate!.month.toString().padLeft(2, '0')}-${releasedDate!.day.toString().padLeft(2, '0')}",
        "percentageMediaHouse": price,
        "revenue": revenue,
        "netRevenue": netRevenue,
        "movieName": movieName,
        "views": views,
      };
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
