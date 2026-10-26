class PurchasedUsersResponse {
  bool? success;
  String? message;
  int? statusCode;
  PurchasedUsersData? data;

  PurchasedUsersResponse({
    this.success,
    this.message,
    this.statusCode,
    this.data,
  });

  factory PurchasedUsersResponse.fromJson(Map<String, dynamic> json) =>
      PurchasedUsersResponse(
        success: json["success"] == true ||
            json["isSuccess"] == true ||
            json["statusCode"] == 200,
        message: json["message"]?.toString(),
        statusCode: json["statusCode"] is int
            ? json["statusCode"]
            : int.tryParse(json["statusCode"]?.toString() ?? ''),
        data: json["data"] != null
            ? PurchasedUsersData.fromJson(
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

class PurchasedUsersData {
  List<PurchasedUserItem> users;
  int totalElements;
  int totalPages;
  int currentPage;
  int pageSize;

  PurchasedUsersData({
    this.users = const [],
    this.totalElements = 0,
    this.totalPages = 0,
    this.currentPage = 0,
    this.pageSize = 10,
  });

  factory PurchasedUsersData.fromJson(Map<String, dynamic> json) {
    List<PurchasedUserItem> parsedUsers = [];
    final rawList = json["content"] ?? json["users"] ?? json["userList"] ?? json["data"];
    if (rawList is List) {
      parsedUsers = rawList
          .whereType<Map>()
          .map((item) => PurchasedUserItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return PurchasedUsersData(
      users: parsedUsers,
      totalElements: _readInt(json["totalElements"] ?? json["totalCount"] ?? parsedUsers.length) ??
          parsedUsers.length,
      totalPages: _readInt(json["totalPages"] ?? 1) ?? 1,
      currentPage: _readInt(json["number"] ?? json["currentPage"] ?? json["page"] ?? 0) ?? 0,
      pageSize: _readInt(json["size"] ?? json["pageSize"] ?? 10) ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        "content": users.map((u) => u.toJson()).toList(),
        "totalElements": totalElements,
        "totalPages": totalPages,
        "currentPage": currentPage,
        "pageSize": pageSize,
      };
}

class PurchasedUserItem {
  int? id;
  int? userId;
  String? userName;
  String? email;
  String? mobileNumber;
  double? amountPaid;
  String? purchaseDate;
  String? state;
  String? city;
  String? country;
  String? paymentStatus;
  String? transactionId;

  PurchasedUserItem({
    this.id,
    this.userId,
    this.userName,
    this.email,
    this.mobileNumber,
    this.amountPaid,
    this.purchaseDate,
    this.state,
    this.city,
    this.country,
    this.paymentStatus,
    this.transactionId,
  });

  factory PurchasedUserItem.fromJson(Map<String, dynamic> json) => PurchasedUserItem(
        id: _readInt(json["id"]),
        userId: _readInt(json["userId"] ?? json["user_id"]),
        userName: json["userName"]?.toString() ??
            json["username"]?.toString() ??
            json["name"]?.toString() ??
            json["fullName"]?.toString(),
        email: json["email"]?.toString() ?? json["emailId"]?.toString(),
        mobileNumber: json["mobileNumber"]?.toString() ??
            json["mobile"]?.toString() ??
            json["phone"]?.toString() ??
            json["contactNumber"]?.toString(),
        amountPaid: _readDouble(json["amountPaid"] ??
            json["amount"] ??
            json["paidAmount"] ??
            json["price"]),
        purchaseDate: json["purchaseDate"]?.toString() ??
            json["date"]?.toString() ??
            json["createdAt"]?.toString() ??
            json["createdDate"]?.toString(),
        state: json["state"]?.toString(),
        city: json["city"]?.toString(),
        country: json["country"]?.toString() ?? "India",
        paymentStatus: json["paymentStatus"]?.toString() ?? json["status"]?.toString() ?? "COMPLETED",
        transactionId: json["transactionId"]?.toString() ?? json["txnId"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "userId": userId,
        "userName": userName,
        "email": email,
        "mobileNumber": mobileNumber,
        "amountPaid": amountPaid,
        "purchaseDate": purchaseDate,
        "state": state,
        "city": city,
        "country": country,
        "paymentStatus": paymentStatus,
        "transactionId": transactionId,
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
