class TopRevenueMovie {
  String? message;
  Data? data;
  int? statusCode;
  bool? success;

  TopRevenueMovie({
    this.message,
    this.data,
    this.statusCode,
    this.success,
  });

  factory TopRevenueMovie.fromJson(Map<String, dynamic> json) => TopRevenueMovie(
    message: json["message"],
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    statusCode: json["statusCode"],
    success: json["success"],
  );

  Map<String, dynamic> toJson() => {
    "message": message,
    "data": data?.toJson(),
    "statusCode": statusCode,
    "success": success,
  };
}

class Data {
  List<ContentWithRevenue>? contentWithRevenue;
  double? totalRevenue;

  Data({
    this.contentWithRevenue,
    this.totalRevenue,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    contentWithRevenue: json["contentWithRevenue"] == null ? [] : List<ContentWithRevenue>.from(json["contentWithRevenue"]!.map((x) => ContentWithRevenue.fromJson(x))),
    totalRevenue: _toDouble(json["totalRevenue"]),
  );

  Map<String, dynamic> toJson() => {
    "contentWithRevenue": contentWithRevenue == null ? [] : List<dynamic>.from(contentWithRevenue!.map((x) => x.toJson())),
    "totalRevenue": totalRevenue,
  };
}

class ContentWithRevenue {
  double? totalRevenue;
  double? mediaHouseGrossRevenue;
  double? mediaHouseNetRevenue;
  String? name;

  ContentWithRevenue({
    this.totalRevenue,
    this.mediaHouseGrossRevenue,
    this.mediaHouseNetRevenue,
    this.name,
  });

  factory ContentWithRevenue.fromJson(Map<String, dynamic> json) => ContentWithRevenue(
    totalRevenue: _toDouble(json["totalRevenue"]),
    mediaHouseGrossRevenue: _toDouble(json["mediaHouseGrossRevenue"]),
    mediaHouseNetRevenue: _toDouble(
      json["mediaHouseNetRevenue"] ?? json["totalRevenue"],
    ),
    name: (json["Name"] ?? json["name"])?.toString(),
  );

  Map<String, dynamic> toJson() => {
    "totalRevenue": totalRevenue,
    "mediaHouseGrossRevenue": mediaHouseGrossRevenue,
    "mediaHouseNetRevenue": mediaHouseNetRevenue,
    "Name": name,
  };
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
