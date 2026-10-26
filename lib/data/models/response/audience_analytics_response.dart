class AudienceAnalyticsResponse {
  bool? success;
  String? message;
  int? statusCode;
  List<AudienceMetricItem> data;

  AudienceAnalyticsResponse({
    this.success,
    this.message,
    this.statusCode,
    this.data = const [],
  });

  factory AudienceAnalyticsResponse.fromJson(dynamic json) {
    if (json is List) {
      return AudienceAnalyticsResponse(
        success: true,
        data: json
            .whereType<Map>()
            .map((item) => AudienceMetricItem.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      List<AudienceMetricItem> parsed = [];
      final rawData = json["data"] ?? json["analytics"] ?? json["result"];
      if (rawData is List) {
        parsed = rawData
            .whereType<Map>()
            .map((item) => AudienceMetricItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else if (rawData is Map) {
        rawData.forEach((key, value) {
          parsed.add(AudienceMetricItem(
            label: key.toString(),
            value: (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0,
          ));
        });
      }

      return AudienceAnalyticsResponse(
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        data: parsed,
      );
    }

    return AudienceAnalyticsResponse(success: false, data: const []);
  }

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "statusCode": statusCode,
        "data": data.map((d) => d.toJson()).toList(),
      };
}

class AudienceMetricItem {
  String label;
  double value;
  int? count;
  double? percentage;

  AudienceMetricItem({
    required this.label,
    required this.value,
    this.count,
    this.percentage,
  });

  factory AudienceMetricItem.fromJson(Map<String, dynamic> json) {
    final rawLabel = json["label"] ??
        json["location"] ??
        json["city"] ??
        json["state"] ??
        json["ageGroup"] ??
        json["age_group"] ??
        json["category"] ??
        json["name"] ??
        "Unknown";

    final rawVal = json["value"] ??
        json["views"] ??
        json["viewCount"] ??
        json["count"] ??
        json["total"] ??
        0;

    final numVal = (rawVal is num)
        ? rawVal.toDouble()
        : double.tryParse(rawVal.toString()) ?? 0.0;

    return AudienceMetricItem(
      label: rawLabel.toString(),
      value: numVal,
      count: (rawVal is num) ? rawVal.toInt() : int.tryParse(rawVal.toString()),
      percentage: json["percentage"] is num
          ? (json["percentage"] as num).toDouble()
          : double.tryParse(json["percentage"]?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        "label": label,
        "value": value,
        "count": count,
        "percentage": percentage,
      };
}
