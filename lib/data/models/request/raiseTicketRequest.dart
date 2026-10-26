class RaiseTicketRequest {
  String? date;
  String? description;
  String? email;
  String? feedback;
  String? image;
  bool? isResolved;
  String? mobileNumber;
  int? tickedId;
  String? topic;
  String? title;
  String? priority;
  String? category;
  int? userId;

  RaiseTicketRequest({
    this.date,
    this.description,
    this.email,
    this.feedback,
    this.image,
    this.isResolved,
    this.mobileNumber,
    this.tickedId,
    this.topic,
    this.title,
    this.priority,
    this.category,
    this.userId,
  });

  factory RaiseTicketRequest.fromJson(Map<String, dynamic> json) => RaiseTicketRequest(
    date: json["date"]?.toString(),
    description: json["description"]?.toString(),
    email: json["email"]?.toString(),
    feedback: json["feedback"]?.toString(),
    image: json["image"]?.toString(),
    isResolved: json["isResolved"] == true,
    mobileNumber: json["mobileNumber"]?.toString(),
    tickedId: json["tickedId"] is int
        ? json["tickedId"]
        : int.tryParse(json["tickedId"]?.toString() ?? ''),
    topic: json["topic"]?.toString() ?? json["title"]?.toString(),
    title: json["title"]?.toString() ?? json["topic"]?.toString(),
    priority: json["priority"]?.toString(),
    category: json["category"]?.toString(),
    userId: json["userId"] is int
        ? json["userId"]
        : int.tryParse(json["userId"]?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    "date": date,
    "description": description,
    "email": email,
    "feedback": feedback,
    "image": image,
    "isResolved": isResolved,
    "mobileNumber": mobileNumber,
    "tickedId": tickedId,
    "topic": topic ?? title,
    "title": title ?? topic,
    if (priority != null && priority!.isNotEmpty) "priority": priority,
    if (category != null && category!.isNotEmpty) "category": category,
    "userId": userId,
  };
}
