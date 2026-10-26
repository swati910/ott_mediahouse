import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/storage/storage_service.dart';
import 'package:media_house/data/models/response/signed_playback.dart';

class SecurePlaybackException implements Exception {
  const SecurePlaybackException(this.message);
  final String message;
}

class SecurePlaybackService {
  SecurePlaybackService({http.Client? client})
      : _client = client ?? http.Client();

  static const _deviceIdKey = 'anti_piracy_installation_device_id';
  static const _storage = FlutterSecureStorage();
  final http.Client _client;

  Future<SignedPlaybackResponse> authorize({
    required String contentId,
    required String playbackUrl,
    required String type,
  }) async {
    final source = Uri.tryParse(playbackUrl.trim());
    if (contentId.trim().isEmpty) {
      throw const SecurePlaybackException('Content is unavailable.');
    }
    if (source == null || source.scheme != 'https' || source.host.isEmpty) {
      throw const SecurePlaybackException(
          'This content has no secure playback source.');
    }
    if (_isYouTube(source)) {
      throw const SecurePlaybackException(
          'YouTube media is not protected content.');
    }

    final token =
        (await StorageService.instance.secureSession.getAccessToken())?.trim();
    if (token == null || token.isEmpty) {
      throw const SecurePlaybackException(
          'Your session has expired. Please sign in again.');
    }

    final request = SignedPlaybackRequest(
      contentId: contentId.trim(),
      playbackUrl: playbackUrl.trim(),
      type: type,
      deviceId: await _deviceId(),
      platform: _platform,
    );
    try {
      final response = await _client.post(
        Uri.parse(ApiConstant.signedPlaybackUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );
      if (response.statusCode == 401) {
        throw const SecurePlaybackException(
            'Your session has expired. Please sign in again.');
      }
      if (response.statusCode == 403) {
        throw const SecurePlaybackException(
            'Playback is not allowed for this content.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const SecurePlaybackException(
            'Secure playback could not be prepared. Please retry.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      final root = Map<String, dynamic>.from(decoded);
      final rawData = root['data'];
      return SignedPlaybackResponse.fromJson(
          rawData is Map ? Map<String, dynamic>.from(rawData) : root);
    } on SecurePlaybackException {
      rethrow;
    } on FormatException {
      throw const SecurePlaybackException(
          'Secure playback returned an invalid response.');
    } on http.ClientException {
      throw const SecurePlaybackException(
          'Check your internet connection and retry.');
    } catch (_) {
      throw const SecurePlaybackException(
          'Secure playback could not be prepared. Please retry.');
    }
  }

  Future<String> _deviceId() async {
    final stored = (await _storage.read(key: _deviceIdKey))?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  static bool _isYouTube(Uri uri) =>
      uri.host.toLowerCase().contains('youtube.com') ||
      uri.host.toLowerCase() == 'youtu.be';

  static String get _platform {
    if (kIsWeb) return 'WEB';
    if (defaultTargetPlatform == TargetPlatform.android) return 'ANDROID';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'IOS';
    return 'UNSUPPORTED';
  }

  void dispose() => _client.close();
}
