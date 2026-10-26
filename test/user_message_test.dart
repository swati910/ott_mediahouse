import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/app/core/utils/user_message.dart';

void main() {
  test('prefers a usable backend message', () {
    expect(
      UserMessage.resolve(
          apiMessage: ' Saved by the server. ', fallbackMessage: 'Fallback.'),
      'Saved by the server.',
    );
  });

  test('reads nested data and validation errors', () {
    expect(
        UserMessage.extract({
          'data': {'message': 'Upload failed.'}
        }),
        'Upload failed.');
    expect(
        UserMessage.extract({
          'errors': {'email': 'Email is already registered.'}
        }),
        'Email is already registered.');
  });

  test('uses fallback for empty or unsafe technical messages', () {
    expect(
      UserMessage.resolve(
          apiMessage: '<html>Server error</html>',
          fallbackMessage: 'Please try again.'),
      'Please try again.',
    );
    expect(UserMessage.sanitize('SocketException: host lookup failed'), isNull);
  });

  test('maps timeouts and important HTTP statuses safely', () {
    expect(
        UserMessage.forException(TimeoutException('late'),
            fallbackMessage: 'Fallback.'),
        'The request timed out. Please try again.');
    expect(UserMessage.forStatus(401, fallbackMessage: 'Fallback.'),
        contains('sign in'));
    expect(UserMessage.forStatus(403, fallbackMessage: 'Fallback.'),
        contains('permission'));
    expect(UserMessage.forStatus(429, fallbackMessage: 'Fallback.'),
        contains('wait'));
    expect(UserMessage.forStatus(500, fallbackMessage: 'Fallback.'),
        contains('later'));
  });
}
