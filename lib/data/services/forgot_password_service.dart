import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/data/models/forgot_password_response.dart';

class ForgotPasswordService {
  ForgotPasswordService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<ForgotPasswordResponse> sendForgotPasswordOtp(
    String mobileNumber,
  ) =>
      _post(ApiConstant.forgotPasswordSendOtp, {
        'mobileNumber': mobileNumber,
      });

  Future<ForgotPasswordResponse> verifyForgotPasswordOtp({
    required String mobileNumber,
    required String otp,
  }) =>
      _post(ApiConstant.forgotPasswordVerifyOtp, {
        'mobileNumber': mobileNumber,
        'otp': otp,
      });

  Future<ForgotPasswordResponse> resetForgotPassword({
    required String mobileNumber,
    required String username,
    required String password,
  }) =>
      _post(ApiConstant.forgotPasswordReset, {
        'mobileNumber': mobileNumber,
        'username': username,
        'password': password,
      });

  Future<ForgotPasswordResponse> _post(
    String endpoint,
    Map<String, String> queryParameters,
  ) async {
    final uri = Uri.parse(endpoint).replace(queryParameters: queryParameters);
    try {
      final response = await _client.post(uri, headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));
      if (response.body.trim().isEmpty) {
        return _failure(
            response.statusCode, 'The server returned an empty response.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return _failure(
            response.statusCode, 'The server returned an unexpected response.');
      }
      final result = ForgotPasswordResponse.fromJson(
        Map<String, dynamic>.from(decoded),
        statusCode: response.statusCode,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return result;
      }
      return ForgotPasswordResponse(
        success: false,
        message: result.message.isNotEmpty
            ? result.message
            : _httpMessage(response.statusCode),
        statusCode: response.statusCode,
      );
    } on TimeoutException {
      return _failure(null, 'The request timed out. Please try again.');
    } on SocketException {
      return _failure(
          null, 'No internet connection. Please check your network.');
    } on FormatException {
      return _failure(null, 'The server returned an unexpected response.');
    } catch (_) {
      return _failure(null, 'Something went wrong. Please try again.');
    }
  }

  ForgotPasswordResponse _failure(int? code, String message) =>
      ForgotPasswordResponse(
          success: false, message: message, statusCode: code);

  String _httpMessage(int code) {
    if (code == 429) {
      return 'Too many requests. Please wait before trying again.';
    }
    if (code == 401 || code == 403) return 'This request is not authorized.';
    if (code >= 500) {
      return 'The server is unavailable. Please try again later.';
    }
    return 'Unable to complete the request. Please try again.';
  }
}
