import 'dart:async';
import 'dart:io';

class UserMessage {
  const UserMessage._();

  static String resolve({
    Object? apiResponse,
    String? apiMessage,
    String? validationMessage,
    required String fallbackMessage,
    int? statusCode,
  }) {
    final candidates = <String?>[
      apiMessage,
      extract(apiResponse),
      validationMessage,
    ];
    for (final candidate in candidates) {
      final safe = sanitize(candidate);
      if (safe != null) {
        return safe;
      }
    }
    if (statusCode != null) {
      return forStatus(statusCode, fallbackMessage: fallbackMessage);
    }
    return sanitize(fallbackMessage) ??
        'Unable to complete the request. Please try again.';
  }

  static String? extract(Object? response) {
    if (response is! Map) {
      return null;
    }
    final map = Map<Object?, Object?>.from(response);
    for (final key in const ['message', 'error', 'detail', 'details']) {
      final value = map[key];
      if (value is String && sanitize(value) != null) {
        return value;
      }
    }
    final dataMessage = extract(map['data']);
    if (dataMessage != null) {
      return dataMessage;
    }
    final errors = map['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is String && sanitize(value) != null) {
          return value;
        }
        if (value is List) {
          for (final item in value) {
            if (item is String && sanitize(item) != null) {
              return item;
            }
          }
        }
      }
    }
    return null;
  }

  static String forException(Object error, {required String fallbackMessage}) {
    if (error is TimeoutException) {
      return 'The request timed out. Please try again.';
    }
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }
    return fallbackMessage;
  }

  static String forStatus(int statusCode, {required String fallbackMessage}) {
    if (statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait and try again.';
    }
    if (statusCode >= 500) {
      return 'Something went wrong. Please try again later.';
    }
    return fallbackMessage;
  }

  static String? sanitize(String? message) {
    final value = message?.trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    final lower = value.toLowerCase();
    final unsafe = value.startsWith('{') ||
        value.startsWith('[') ||
        lower.contains('<html') ||
        lower.contains('<!doctype') ||
        lower.contains('exception:') ||
        lower.contains('stack trace') ||
        lower.contains('instance of ') ||
        lower.contains('jdbc') ||
        lower.contains('sqlstate') ||
        lower.contains('https://') ||
        lower.contains('http://');
    if (unsafe) {
      return null;
    }
    return value;
  }
}
