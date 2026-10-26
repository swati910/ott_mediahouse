import 'package:media_house/domain/entities/mediaHouse.dart';

class GetMediaHouse {
  String? message;
  Data? data;
  int? statusCode;
  bool? success;

  GetMediaHouse({
    this.message,
    this.data,
    this.statusCode,
    this.success,
  });

  factory GetMediaHouse.fromJson(Map<String, dynamic> json) => GetMediaHouse(
        message: json["message"]?.toString(),
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data": data?.toJson(),
        "statusCode": statusCode,
        "success": success,
      };
}

class Data {
  MediaHouse? mediaHouse;

  Data({
    this.mediaHouse,
  });

  factory Data.fromJson(dynamic rawData) {
    if (rawData is! Map<String, dynamic>) {
      if (rawData is Map) {
        rawData = Map<String, dynamic>.from(rawData);
      } else {
        return Data();
      }
    }
    final nested = rawData["MediaHouse"] ?? rawData["mediaHouse"] ?? rawData;
    return Data(
      mediaHouse: nested is Map<String, dynamic>
          ? MediaHouse.fromJson(nested)
          : nested is Map
              ? MediaHouse.fromJson(Map<String, dynamic>.from(nested))
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        "MediaHouse": mediaHouse?.toJson(),
      };
}