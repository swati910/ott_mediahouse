class GraphResponse {
  String? message;
  List<GraphData>? data;
  int? statusCode;
  bool? success;

  GraphResponse({
    this.message,
    this.data,
    this.statusCode,
    this.success,
  });

  factory GraphResponse.fromJson(Map<String, dynamic> json) => GraphResponse(
        message: json["message"],
        data: json["data"] == null
            ? []
            : List<GraphData>.from(
                json["data"]!.map((x) => GraphData.fromJson(x)),
              ),
        statusCode: json["statusCode"],
        success: json["success"],
      );

  Map<String, dynamic> toJson() => {
        "message": message,
        "data":
            data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "statusCode": statusCode,
        "success": success,
      };
}

class GraphData {
  String? label;
  double? value;

  GraphData({
    this.label,
    this.value,
  });

  factory GraphData.fromJson(Map<String, dynamic> json) => GraphData(
        label: json["label"]?.toString(),
        value: json["value"] is num
            ? (json["value"] as num).toDouble()
            : double.tryParse(json["value"]?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        "label": label,
        "value": value,
      };
}
