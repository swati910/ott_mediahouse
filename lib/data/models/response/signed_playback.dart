class SignedPlaybackRequest {
  const SignedPlaybackRequest({
    required this.contentId,
    required this.playbackUrl,
    required this.type,
    required this.deviceId,
    required this.platform,
    this.country = 'IN',
  });

  final String contentId;
  final String playbackUrl;
  final String type;
  final String deviceId;
  final String platform;
  final String country;

  Map<String, dynamic> toJson() => {
        'contentId': contentId,
        'playbackUrl': playbackUrl,
        'country': country,
        'type': type,
        'deviceId': deviceId,
        'platform': platform,
        'deviceIntegrity': const {
          'rooted': false,
          'jailbroken': false,
          'emulator': false,
        },
      };
}

class SignedPlaybackResponse {
  const SignedPlaybackResponse({
    required this.playbackUrl,
    required this.authorizationType,
    required this.cookies,
    required this.sessionId,
    required this.expiresAt,
  });

  static const signedCookies = 'CLOUDFRONT_SIGNED_COOKIES';
  static const signedUrl = 'CLOUDFRONT_SIGNED_URL';
  static const requiredCookies = {
    'CloudFront-Policy',
    'CloudFront-Signature',
    'CloudFront-Key-Pair-Id',
  };

  final String playbackUrl;
  final String authorizationType;
  final Map<String, String> cookies;
  final String sessionId;
  final DateTime expiresAt;

  String get cookieHeader =>
      requiredCookies.map((name) => '$name=${cookies[name]}').join('; ');

  Map<String, String> get httpHeaders => authorizationType == signedCookies
      ? Map.unmodifiable({'Cookie': cookieHeader})
      : const {};

  factory SignedPlaybackResponse.fromJson(Map<String, dynamic> json) {
    final signedUrlValue = (json['signedUrl'] ?? '').toString().trim();
    final normalizedUrl = signedUrlValue.isNotEmpty
        ? signedUrlValue
        : (json['playbackUrl'] ?? '').toString().trim();
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Invalid secure playback URL.');
    }

    final authorizationType =
        (json['authorizationType'] ?? '').toString().trim().toUpperCase();
    if (authorizationType != signedCookies && authorizationType != signedUrl) {
      throw const FormatException('Unsupported playback authorization.');
    }

    final rawCookies = json['cookies'];
    final cookies = rawCookies is Map
        ? rawCookies.map(
            (key, value) => MapEntry(key.toString(), value.toString().trim()))
        : <String, String>{};
    if (authorizationType == signedCookies &&
        !requiredCookies.every((name) {
          final value = cookies[name];
          return value != null &&
              value.isNotEmpty &&
              !value.contains(RegExp(r'[;\r\n]'));
        })) {
      throw const FormatException('Missing playback authorization.');
    }

    final sessionId = (json['sessionId'] ?? '').toString().trim();
    if (sessionId.isEmpty) {
      throw const FormatException('Missing secure playback session.');
    }

    final rawEpoch = json['expiresAtEpochSeconds'];
    final epoch = rawEpoch is num
        ? rawEpoch.toInt()
        : int.tryParse(rawEpoch?.toString() ?? '');
    final expiresAt = epoch != null && epoch > 0
        ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000, isUtc: true)
        : DateTime.tryParse((json['expiresAt'] ?? '').toString())?.toUtc();
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const FormatException('Playback authorization has expired.');
    }

    return SignedPlaybackResponse(
      playbackUrl: normalizedUrl,
      authorizationType: authorizationType,
      cookies: Map.unmodifiable(cookies),
      sessionId: sessionId,
      expiresAt: expiresAt,
    );
  }
}

String secureContentType(String? value, {bool episode = false}) {
  if (episode) return 'EPISODE';
  final normalized =
      (value ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s-]+'), '_');
  switch (normalized) {
    case 'SHORT':
    case 'SHORTS':
    case 'SHORTFILM':
    case 'SHORT_FILM':
      return 'SHORT_FILM';
    case 'MINISERIES':
    case 'MINI_SERIES':
      return 'MINI_SERIES';
    case 'MOVIE':
    case 'FILM':
    default:
      return 'MOVIE';
  }
}
