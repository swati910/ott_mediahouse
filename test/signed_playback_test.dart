import 'package:flutter_test/flutter_test.dart';
import 'package:media_house/data/models/response/signed_playback.dart';

void main() {
  test('secure content type mapping is centralized', () {
    expect(secureContentType('movie'), 'MOVIE');
    expect(secureContentType('short film'), 'SHORT_FILM');
    expect(secureContentType('mini-series'), 'MINI_SERIES');
    expect(secureContentType('series', episode: true), 'EPISODE');
  });

  test('signed cookie response builds the CloudFront Cookie header', () {
    final response = SignedPlaybackResponse.fromJson({
      'playbackUrl': 'https://cdn.example.com/master.m3u8',
      'authorizationType': 'CLOUDFRONT_SIGNED_COOKIES',
      'cookies': {
        'CloudFront-Policy': 'policy',
        'CloudFront-Signature': 'signature',
        'CloudFront-Key-Pair-Id': 'key',
      },
      'sessionId': 'session',
      'expiresAtEpochSeconds': DateTime.now()
              .toUtc()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch ~/
          1000,
    });

    expect(response.httpHeaders, {
      'Cookie':
          'CloudFront-Policy=policy; CloudFront-Signature=signature; CloudFront-Key-Pair-Id=key',
    });
  });

  test('signed response rejects missing CloudFront credentials', () {
    expect(
      () => SignedPlaybackResponse.fromJson({
        'playbackUrl': 'https://cdn.example.com/master.m3u8',
        'authorizationType': 'CLOUDFRONT_SIGNED_COOKIES',
        'cookies': {'CloudFront-Policy': 'policy'},
        'sessionId': 'session',
        'expiresAtEpochSeconds': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
      }),
      throwsFormatException,
    );
  });
}
