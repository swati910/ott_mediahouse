import 'package:media_house/data/models/response/getRaisedTicketListResponse.dart';

class TicketSearchFilterResponse {
  bool? success;
  String? message;
  int? statusCode;
  List<TicketRaised> data;
  int? totalElements;
  int? totalPages;

  TicketSearchFilterResponse({
    this.success,
    this.message,
    this.statusCode,
    this.data = const [],
    this.totalElements,
    this.totalPages,
  });

  factory TicketSearchFilterResponse.fromJson(dynamic json) {
    if (json is List) {
      return TicketSearchFilterResponse(
        success: true,
        data: json
            .whereType<Map>()
            .map((item) => TicketRaised.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }

    if (json is Map<String, dynamic>) {
      List<TicketRaised> tickets = [];
      final rawData = json["data"] ?? json["tickets"] ?? json["content"] ?? json["ticketRaised"];
      if (rawData is List) {
        tickets = rawData
            .whereType<Map>()
            .map((item) => TicketRaised.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      } else if (rawData is Map && rawData["ticketRaised"] is List) {
        tickets = (rawData["ticketRaised"] as List)
            .whereType<Map>()
            .map((item) => TicketRaised.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }

      return TicketSearchFilterResponse(
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        data: tickets,
        totalElements: json["totalElements"] is int
            ? json["totalElements"]
            : int.tryParse(json["totalElements"]?.toString() ?? ''),
        totalPages: json["totalPages"] is int
            ? json["totalPages"]
            : int.tryParse(json["totalPages"]?.toString() ?? ''),
      );
    }

    return TicketSearchFilterResponse(success: false, data: const []);
  }

  Map<String, dynamic> toJson() => {
        "success": success,
        "message": message,
        "statusCode": statusCode,
        "data": data.map((t) => t.toJson()).toList(),
      };
}
