import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:universal_html/html.dart' as html;

class MultipartSessionRecord {
  final dynamic uploadSessionId;
  final String uploadId;
  final String key;
  final int partSize;
  final int totalParts;
  final String contentId;
  final String fileName;
  final int fileSize;
  final String mimeType;
  final int lastModified;
  final String localTaskId;
  String status;
  Map<int, String> uploadedETags;

  MultipartSessionRecord({
    required this.uploadSessionId,
    required this.uploadId,
    required this.key,
    required this.partSize,
    required this.totalParts,
    required this.contentId,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.lastModified,
    required this.localTaskId,
    required this.status,
    required this.uploadedETags,
  });

  Map<String, dynamic> toJson() {
    return {
      'uploadSessionId': uploadSessionId,
      'uploadId': uploadId,
      'key': key,
      'partSize': partSize,
      'totalParts': totalParts,
      'contentId': contentId,
      'fileName': fileName,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'lastModified': lastModified,
      'localTaskId': localTaskId,
      'status': status,
      'uploadedETags': uploadedETags.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  static String _ensureQuotedETag(String etag) {
    final trimmed = etag.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('"') && trimmed.endsWith('"') && trimmed.length >= 2) {
      return trimmed;
    }
    final clean = trimmed.replaceAll('"', '');
    return '"$clean"';
  }

  factory MultipartSessionRecord.fromJson(Map<String, dynamic> json) {
    final etagMapRaw = json['uploadedETags'] as Map<String, dynamic>? ?? {};
    final Map<int, String> parsedETags = {};
    etagMapRaw.forEach((k, v) {
      final pNum = int.tryParse(k);
      if (pNum != null && v is String) {
        parsedETags[pNum] = _ensureQuotedETag(v);
      }
    });

    return MultipartSessionRecord(
      uploadSessionId: json['uploadSessionId'],
      uploadId: json['uploadId'] ?? '',
      key: json['key'] ?? '',
      partSize: json['partSize'] ?? 0,
      totalParts: json['totalParts'] ?? 0,
      contentId: json['contentId'] ?? '',
      fileName: json['fileName'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      mimeType: json['mimeType'] ?? '',
      lastModified: json['lastModified'] ?? 0,
      localTaskId: json['localTaskId'] ?? '',
      status: json['status'] ?? 'idle',
      uploadedETags: parsedETags,
    );
  }
}

class MultipartUploadPersistence {
  static const String _storagePrefix = 'filmytell_multipart_session_';

  static String _key(String localTaskId) => '$_storagePrefix$localTaskId';

  static void saveSession(MultipartSessionRecord record) {
    if (!kIsWeb) return;
    try {
      final jsonStr = jsonEncode(record.toJson());
      html.window.localStorage[_key(record.localTaskId)] = jsonStr;
    } catch (e) {
      debugPrint('Failed to persist multipart session: $e');
    }
  }

  static MultipartSessionRecord? getSession(String localTaskId) {
    if (!kIsWeb) return null;
    try {
      final raw = html.window.localStorage[_key(localTaskId)];
      if (raw == null || raw.isEmpty) return null;
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return MultipartSessionRecord.fromJson(decoded);
    } catch (e) {
      debugPrint('Failed to read persisted multipart session: $e');
      return null;
    }
  }

  static void removeSession(String localTaskId) {
    if (!kIsWeb) return;
    try {
      html.window.localStorage.remove(_key(localTaskId));
    } catch (e) {
      debugPrint('Failed to remove multipart session: $e');
    }
  }

  static void clearAllSessions() {
    if (!kIsWeb) return;
    try {
      final keys = html.window.localStorage.keys.toList();
      for (final k in keys) {
        if (k.startsWith(_storagePrefix)) {
          html.window.localStorage.remove(k);
        }
      }
    } catch (e) {
      debugPrint('Failed to clear all multipart sessions: $e');
    }
  }

  static List<MultipartSessionRecord> getAllSessions() {
    if (!kIsWeb) return [];
    final List<MultipartSessionRecord> list = [];
    try {
      final keys = html.window.localStorage.keys;
      for (final k in keys) {
        if (k.startsWith(_storagePrefix)) {
          final raw = html.window.localStorage[k];
          if (raw != null && raw.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(raw);
            list.add(MultipartSessionRecord.fromJson(decoded));
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get all multipart sessions: $e');
    }
    return list;
  }
}
