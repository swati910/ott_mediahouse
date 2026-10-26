import '../../../domain/entities/user.dart';

class GetRaiseTicketListResponse {
  Data? data;
  String? message;
  int? status;

  GetRaiseTicketListResponse({
    this.data,
    this.message,
    this.status,
  });

  factory GetRaiseTicketListResponse.fromJson(Map<String, dynamic> json) => GetRaiseTicketListResponse(
    data: json["data"] == null ? null : Data.fromJson(json["data"]),
    message: json["message"]?.toString(),
    status: json["status"] is int
        ? json["status"]
        : int.tryParse(json["status"]?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    "data": data?.toJson(),
    "message": message,
    "status": status,
  };
}

class Data {
  List<TicketRaised>? ticketRaised;

  Data({
    this.ticketRaised,
  });

  factory Data.fromJson(Map<String, dynamic> json) => Data(
    ticketRaised: json["TicketRaised"] == null
        ? (json["ticketRaised"] == null
            ? []
            : List<TicketRaised>.from(json["ticketRaised"]!.map((x) => TicketRaised.fromJson(x))))
        : List<TicketRaised>.from(json["TicketRaised"]!.map((x) => TicketRaised.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "TicketRaised": ticketRaised == null ? [] : List<dynamic>.from(ticketRaised!.map((x) => x.toJson())),
  };
}

class TicketRaised {
  int? tickedId;
  String? topic;
  String? title;
  String? priority;
  String? category;
  String? mobileNumber;
  String? email;
  User? user;
  int? userId;
  int? date;
  String? feedback;
  String? image;
  String? description;
  bool? isResolved;

  TicketRaised({
    this.tickedId,
    this.topic,
    this.title,
    this.priority,
    this.category,
    this.mobileNumber,
    this.email,
    this.user,
    this.userId,
    this.date,
    this.feedback,
    this.image,
    this.description,
    this.isResolved,
  });

  factory TicketRaised.fromJson(Map<String, dynamic> json) => TicketRaised(
    tickedId: json["tickedId"] is int
        ? json["tickedId"]
        : int.tryParse(json["tickedId"]?.toString() ?? json["id"]?.toString() ?? ''),
    topic: json["topic"]?.toString() ?? json["title"]?.toString(),
    title: json["title"]?.toString() ?? json["topic"]?.toString(),
    priority: json["priority"]?.toString() ?? "MEDIUM",
    category: json["category"]?.toString() ?? "GENERAL",
    mobileNumber: json["mobileNumber"]?.toString() ?? json["phone"]?.toString(),
    email: json["email"]?.toString(),
    user: json["user"] == null ? null : User.fromJson(json["user"]),
    userId: json["userId"] is int
        ? json["userId"]
        : int.tryParse(json["userId"]?.toString() ?? ''),
    date: json["date"] is int
        ? json["date"]
        : int.tryParse(json["date"]?.toString() ?? ''),
    feedback: json["feedback"]?.toString(),
    image: json["image"]?.toString(),
    description: json["description"]?.toString(),
    isResolved: json["isResolved"] == true || json["resolved"] == true,
  );

  Map<String, dynamic> toJson() => {
    "tickedId": tickedId,
    "topic": topic,
    "title": title,
    "priority": priority,
    "category": category,
    "mobileNumber": mobileNumber,
    "email": email,
    "user": user?.toJson(),
    "userId": userId,
    "date": date,
    "feedback": feedback,
    "image": image,
    "description": description,
    "isResolved": isResolved,
  };
}
