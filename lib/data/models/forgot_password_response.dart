class ForgotPasswordResponse {
  const ForgotPasswordResponse({
    required this.success,
    required this.message,
    this.username,
    this.statusCode,
  });

  final bool success;
  final String message;
  final String? username;
  final int? statusCode;

  factory ForgotPasswordResponse.fromJson(
    Map<String, dynamic> json, {
    int? statusCode,
  }) {
    final data = json['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;
    final rawSuccess = json['success'] ?? json['status'];
    final success = rawSuccess == true ||
        rawSuccess == 1 ||
        rawSuccess?.toString().toLowerCase() == 'success' ||
        rawSuccess?.toString().toLowerCase() == 'true';
    final username = dataMap?['username'] ?? json['username'];
    return ForgotPasswordResponse(
      success: success,
      message: (json['message'] ?? json['error'] ?? '').toString(),
      username: username?.toString(),
      statusCode: statusCode,
    );
  }
}
