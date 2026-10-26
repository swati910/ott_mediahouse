import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_house/data/models/forgot_password_response.dart';
import 'package:media_house/data/services/forgot_password_service.dart';

void main() {
  test('response model supports boolean success and username data', () {
    final response = ForgotPasswordResponse.fromJson({
      'success': true,
      'message': 'Verified',
      'data': {'username': 'user-name'},
    });
    expect(response.success, isTrue);
    expect(response.message, 'Verified');
    expect(response.username, 'user-name');
  });

  test('send OTP uses POST with encoded query parameters', () async {
    late http.Request captured;
    final service = ForgotPasswordService(client: MockClient((request) async {
      captured = request;
      return http.Response(
          jsonEncode({'success': true, 'message': 'Sent'}), 200);
    }));

    final result = await service.sendForgotPasswordOtp('9876543210');

    expect(result.success, isTrue);
    expect(captured.method, 'POST');
    expect(captured.url.queryParameters['mobileNumber'], '9876543210');
  });

  test('backend error message is retained for non-2xx responses', () async {
    final service = ForgotPasswordService(
        client: MockClient((_) async => http.Response(
            jsonEncode({'success': false, 'message': 'OTP expired'}), 400)));

    final result = await service.verifyForgotPasswordOtp(
      mobileNumber: '9876543210',
      otp: '111111',
    );

    expect(result.success, isFalse);
    expect(result.message, 'OTP expired');
  });

  test('429 receives a wait message when backend has no message', () async {
    final service = ForgotPasswordService(
        client: MockClient(
      (_) async => http.Response(jsonEncode({'success': false}), 429),
    ));

    final result = await service.sendForgotPasswordOtp('9876543210');

    expect(result.success, isFalse);
    expect(result.message, contains('wait'));
  });
}
