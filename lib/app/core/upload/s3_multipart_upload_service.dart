import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

import '../auth/auth_service.dart';
import '../constant/api_constant.dart';
import '../network/api_helper.dart';
import 'multipart_upload_persistence.dart';

enum MultipartUploadState {
  idle,
  initiating,
  uploading,
  paused,
  resuming,
  completing,
  completed,
  failed,
  aborted,
}

class MultipartProgressInfo {
  final MultipartUploadState state;
  final double percentage;
  final int uploadedBytes;
  final int totalBytes;
  final int completedParts;
  final int totalParts;
  final double speedBytesPerSec;
  final int remainingSeconds;
  final String? errorMessage;
  final String localTaskId;
  final String videoUrl;

  MultipartProgressInfo({
    required this.state,
    required this.percentage,
    required this.uploadedBytes,
    required this.totalBytes,
    required this.completedParts,
    required this.totalParts,
    required this.speedBytesPerSec,
    required this.remainingSeconds,
    this.errorMessage,
    required this.localTaskId,
    this.videoUrl = '',
  });

  factory MultipartProgressInfo.idle(String taskId) {
    return MultipartProgressInfo(
      state: MultipartUploadState.idle,
      percentage: 0.0,
      uploadedBytes: 0,
      totalBytes: 0,
      completedParts: 0,
      totalParts: 0,
      speedBytesPerSec: 0.0,
      remainingSeconds: 0,
      localTaskId: taskId,
      videoUrl: '',
    );
  }
}

class GlobalS3ConcurrencyLimiter {
  static int maxConcurrentRequests = 4;
  static int _activeRequests = 0;
  static final List<Completer<void>> _queue = [];

  static Future<void> acquire() async {
    if (_activeRequests < maxConcurrentRequests) {
      _activeRequests++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  static void release() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next.complete();
    } else {
      _activeRequests = max(0, _activeRequests - 1);
    }
  }
}

class S3MultipartUploadTask {
  final String localTaskId;
  html.File? file;
  final String contentId;

  MultipartUploadState state = MultipartUploadState.idle;
  dynamic uploadSessionId;
  String uploadId = '';
  String key = '';
  int partSize = 0;
  int totalParts = 0;
  int fileSize = 0;
  String fileName = '';
  String mimeType = '';
  int lastModified = 0;
  String? errorMessage;
  String videoUrl = '';

  final Map<int, String> completedETags = {};
  final Map<int, int> partBytesInFlight = {};
  final Set<int> activePartNumbers = {};
  final Map<int, html.HttpRequest> activeXhrs = {};

  bool _pauseRequested = false;
  bool _cancelRequested = false;
  bool _completingInProgress = false;

  int _uploadedBytesConfirmed = 0;
  DateTime? _uploadStartTime;
  int _bytesUploadedSinceStart = 0;

  final void Function(MultipartProgressInfo info)? onProgress;

  S3MultipartUploadTask({
    required this.localTaskId,
    this.file,
    required this.contentId,
    this.onProgress,
  }) {
    if (file != null) {
      updateFileHandle(file!);
    }
  }

  void updateFileHandle(html.File newFile) {
    file = newFile;
    fileName = newFile.name;
    fileSize = newFile.size;
    mimeType = newFile.type.isNotEmpty ? newFile.type : 'video/mp4';
    lastModified = newFile.lastModified ?? 0;
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

  static String _sanitizeUrl(String url) {
    if (url.isEmpty) return url;
    try {
      final uri = Uri.parse(url);
      if (uri.hasQuery) {
        return '${uri.scheme}://${uri.host}${uri.path}?...REDACTED';
      }
      return url;
    } catch (_) {
      return 'URL_REDACTED';
    }
  }

  static String _formatHeadersWithAuthRedacted(Map<String, String> headers) {
    final copy = Map<String, String>.from(headers);
    if (copy.containsKey('Authorization')) {
      copy['Authorization'] = 'Bearer ***REDACTED***';
    }
    if (copy.containsKey('authorization')) {
      copy['authorization'] = 'Bearer ***REDACTED***';
    }
    return copy.toString();
  }

  double _lastLoggedPct = -1.0;
  DateTime? _lastProgressLogTime;

  void notifyProgress() {
    int currentUploadedBytes = _uploadedBytesConfirmed;
    partBytesInFlight.forEach((_, bytes) {
      currentUploadedBytes += bytes;
    });
    currentUploadedBytes = min(currentUploadedBytes, fileSize);

    double pct = fileSize > 0 ? (currentUploadedBytes / fileSize) * 100.0 : 0.0;
    pct = pct.clamp(0.0, 100.0);

    double speed = 0.0;
    int remainingSec = 0;
    if (state == MultipartUploadState.uploading && _uploadStartTime != null) {
      final elapsedSec =
          DateTime.now().difference(_uploadStartTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0.5 && _bytesUploadedSinceStart > 0) {
        speed = _bytesUploadedSinceStart / elapsedSec;
        final remainingBytes = fileSize - currentUploadedBytes;
        if (speed > 0) {
          remainingSec = (remainingBytes / speed).ceil();
        }
      }
    }

    final now = DateTime.now();
    if (state == MultipartUploadState.uploading &&
        (_lastProgressLogTime == null ||
            now.difference(_lastProgressLogTime!).inMilliseconds >= 1000 ||
            (pct - _lastLoggedPct).abs() >= 1.0)) {
      _lastLoggedPct = pct;
      _lastProgressLogTime = now;

      final samplePart = partBytesInFlight.isNotEmpty ? partBytesInFlight.keys.first : 1;
      final sampleBytes = partBytesInFlight[samplePart] ?? 0;
      final samplePartSize = (samplePart * partSize > fileSize)
          ? max(0, fileSize - (samplePart - 1) * partSize)
          : partSize;
      final samplePartPct = samplePartSize > 0 ? (sampleBytes / samplePartSize) * 100.0 : 0.0;

      debugPrint('''
========== S3 PART PROGRESS ==========
partNumber: $samplePart
bytesSent: $sampleBytes
partTotalBytes: $samplePartSize
partProgress: ${samplePartPct.toStringAsFixed(1)}%
totalUploadedBytes: $currentUploadedBytes
totalFileBytes: $fileSize
overallProgress: ${pct.toStringAsFixed(1)}%
overallPercent: ${pct.toStringAsFixed(1)}%
activeUploads: ${GlobalS3ConcurrencyLimiter._activeRequests}
======================================''');
    }

    onProgress?.call(MultipartProgressInfo(
      state: state,
      percentage: pct,
      uploadedBytes: currentUploadedBytes,
      totalBytes: fileSize,
      completedParts: completedETags.length,
      totalParts: totalParts,
      speedBytesPerSec: speed,
      remainingSeconds: remainingSec,
      errorMessage: errorMessage,
      localTaskId: localTaskId,
      videoUrl: videoUrl,
    ));
  }

  static String? validateFile(html.File? f, String cid) {
    if (f == null) return 'No video file selected.';
    if (f.size <= 0) return 'Selected file is empty (0 bytes).';
    const maxSizeBytes = 500 * 1024 * 1024 * 1024; // 500 GB
    if (f.size > maxSizeBytes) return 'File size exceeds 500 GB limit.';

    final cleanCid = cid.trim();
    if (cleanCid.isEmpty || cleanCid == 'null' || cleanCid == 'undefined') {
      return 'Invalid or missing content ID.';
    }

    final ext =
        f.name.contains('.') ? f.name.split('.').last.toLowerCase() : '';
    const allowed = ['mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v', '3gp', 'ts'];
    if (ext.isNotEmpty && !allowed.contains(ext)) {
      return 'Unsupported video extension (.$ext). Supported extensions: ${allowed.join(', ')}.';
    }

    return null;
  }

  Future<void> startOrResume({html.File? reselectedFile}) async {
    _pauseRequested = false;
    _cancelRequested = false;
    errorMessage = null;

    final targetFile = reselectedFile ?? file;
    if (targetFile == null) {
      _setError('Please select the video file to upload.');
      return;
    }

    final validationError = validateFile(targetFile, contentId);
    if (validationError != null) {
      _setError(validationError);
      return;
    }

    final savedSession = MultipartUploadPersistence.getSession(localTaskId);
    if (savedSession != null && savedSession.uploadSessionId != null) {
      state = MultipartUploadState.resuming;
      notifyProgress();

      if (targetFile.name != savedSession.fileName ||
          targetFile.size != savedSession.fileSize) {
        _setError(
            'Selected file does not match the previous incomplete upload session. Please select the same file.');
        return;
      }

      uploadSessionId = savedSession.uploadSessionId;
      uploadId = savedSession.uploadId;
      key = savedSession.key;
      partSize = savedSession.partSize;
      totalParts = savedSession.totalParts;
      completedETags.clear();
      savedSession.uploadedETags.forEach((pNum, tag) {
        completedETags[pNum] = _ensureQuotedETag(tag);
      });

      final statusReconciled = await _reconcileWithStatusApi();
      if (!statusReconciled) {
        debugPrint(
            '[Direct S3 Upload] Session status check failed. Initiating fresh session.');
        MultipartUploadPersistence.removeSession(localTaskId);
        await _initiateNewSession(targetFile);
      }
    } else {
      await _initiateNewSession(targetFile);
    }

    if (state == MultipartUploadState.failed ||
        state == MultipartUploadState.aborted) {
      return;
    }

    await _processUploadLoop(targetFile);
  }

  Future<void> _initiateNewSession(html.File targetFile) async {
    state = MultipartUploadState.initiating;
    notifyProgress();

    final ext =
        targetFile.name.contains('.') ? targetFile.name.split('.').last : '';
    final sizeMb = (targetFile.size / (1024 * 1024)).toStringAsFixed(2);
    final sizeGb = (targetFile.size / (1024 * 1024 * 1024)).toStringAsFixed(3);
    final cType = targetFile.type.isNotEmpty ? targetFile.type : 'video/mp4';

    debugPrint('''
========== MOVIE UPLOAD START ==========
fileName: ${targetFile.name}
fileSize: ${targetFile.size}
fileSizeMB: $sizeMb MB
fileSizeGB: $sizeGb GB
contentType: $cType
extension: $ext
=========================================''');

    try {
      final payload = {
        'fileName': targetFile.name,
        'contentType': cType,
        'fileSize': targetFile.size,
        'contentId': contentId.trim(),
      };

      final authHdrs = await AuthService.authHeaders();
      final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

      debugPrint('''
========== MULTIPART INITIATE REQUEST ==========
URL: ${ApiConstant.multipartInitiate}
METHOD: POST
HEADERS: $redactedHdrs
BODY: ${jsonEncode(payload)}
=================================================''');

      final apiHelper = ApiHelper();
      final response = await apiHelper.postApiWithBody(
          ApiConstant.multipartInitiate, payload);

      debugPrint('''
========== MULTIPART INITIATE RESPONSE ==========
STATUS: ${response.statusCode}
BODY: ${response.body}
==================================================''');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg = _extractErrorMessage(response.body,
            'Failed to initiate upload session (${response.statusCode})');
        _setError(msg);
        return;
      }

      final Map<String, dynamic> bodyJson = jsonDecode(response.body);
      final data = bodyJson['data'] as Map<String, dynamic>?;

      if (data == null) {
        _setError('Initiate upload returned invalid response format.');
        return;
      }

      uploadSessionId = data['uploadSessionId'];
      uploadId = data['uploadId']?.toString() ?? '';
      key = data['key']?.toString() ?? '';
      partSize =
          data['partSize'] != null ? int.parse(data['partSize'].toString()) : 0;

      final serverTotalParts = data['totalParts'] != null
          ? int.parse(data['totalParts'].toString())
          : 0;
      if (partSize > 0) {
        final calculatedParts = (targetFile.size / partSize).ceil();
        totalParts = serverTotalParts > 0 ? serverTotalParts : calculatedParts;
      } else {
        totalParts = serverTotalParts;
      }

      debugPrint('''
========== MULTIPART INITIATED ==========
uploadSessionId: $uploadSessionId
uploadId: $uploadId
s3Key: $key
partSize: $partSize
totalParts: $totalParts
=========================================''');

      if (uploadSessionId == null ||
          uploadId.isEmpty ||
          key.isEmpty ||
          partSize <= 0 ||
          totalParts <= 0) {
        _setError('Initiate API returned incomplete upload session details.');
        return;
      }

      completedETags.clear();
      _saveCurrentSessionRecord();
    } catch (e) {
      debugPrint('[Direct S3 Upload] ❌ Initiate exception: $e');
      _setError('Network error while initiating upload: $e');
    }
  }

  Future<bool> _reconcileWithStatusApi() async {
    try {
      final apiHelper = ApiHelper();
      final url = ApiConstant.multipartStatus(uploadSessionId);
      final authHdrs = await AuthService.authHeaders();
      final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

      debugPrint('''
========== MULTIPART STATUS REQUEST ==========
URL: $url
METHOD: GET
HEADERS: $redactedHdrs
BODY: None
===============================================''');

      final response = await apiHelper.getApi(url);

      debugPrint('''
========== MULTIPART STATUS RESPONSE ==========
STATUS: ${response.statusCode}
BODY: ${response.body}
================================================''');

      if (response.statusCode != 200) {
        return false;
      }

      final Map<String, dynamic> bodyJson = jsonDecode(response.body);
      final data = bodyJson['data'] as Map<String, dynamic>? ?? bodyJson;

      final serverStatus = data['status']?.toString().toUpperCase();
      if (serverStatus == 'COMPLETED' || serverStatus == 'ABORTED') {
        return false;
      }

      if (data['partSize'] != null) {
        partSize = int.parse(data['partSize'].toString());
      }
      if (data['totalParts'] != null) {
        totalParts = int.parse(data['totalParts'].toString());
      }
      if (data['key'] != null && data['key'].toString().isNotEmpty) {
        key = data['key'].toString();
      }
      if (data['uploadId'] != null && data['uploadId'].toString().isNotEmpty) {
        uploadId = data['uploadId'].toString();
      }

      final uploadedPartsRaw = data['uploadedParts'] as List<dynamic>? ?? [];
      completedETags.clear();
      for (final p in uploadedPartsRaw) {
        if (p is Map) {
          final pNum = p['partNumber'];
          final eTag = p['eTag']?.toString();
          if (pNum != null && eTag != null && eTag.isNotEmpty) {
            completedETags[int.parse(pNum.toString())] = _ensureQuotedETag(eTag);
          }
        }
      }
      debugPrint(
          '[Direct S3 Upload] Status reconciled -> status: $serverStatus, completedParts: ${completedETags.length}/$totalParts');
      _saveCurrentSessionRecord();
      return true;
    } catch (e) {
      debugPrint('[Direct S3 Upload] ❌ Status check error: $e');
      return false;
    }
  }

  Future<void> _processUploadLoop(html.File targetFile) async {
    state = MultipartUploadState.uploading;
    _uploadStartTime = DateTime.now();
    _bytesUploadedSinceStart = 0;
    _recalculateConfirmedBytes();
    notifyProgress();

    final List<int> missingParts = [];
    for (int p = 1; p <= totalParts; p++) {
      if (!completedETags.containsKey(p)) {
        missingParts.add(p);
      }
    }

    debugPrint(
        '[Direct S3 Upload] Starting upload loop for ${missingParts.length} missing parts out of $totalParts total parts.');

    if (missingParts.isEmpty) {
      await _completeUpload();
      return;
    }

    const presignBatchSize = 20;
    while (missingParts.isNotEmpty && !_pauseRequested && !_cancelRequested) {
      final batchPartNumbers = missingParts.sublist(
        0,
        min(presignBatchSize, missingParts.length),
      );

      Map<int, String> presignedUrls;
      try {
        presignedUrls = await _fetchPresignedUrls(batchPartNumbers);
      } catch (e) {
        _setError('Failed to fetch upload presigned URLs: $e');
        return;
      }

      bool batchFailed = false;
      final List<Future<bool>> uploadFutures = [];

      for (final pNum in batchPartNumbers) {
        if (_pauseRequested || _cancelRequested) break;
        final url = presignedUrls[pNum];
        if (url == null || url.isEmpty) {
          batchFailed = true;
          break;
        }

        uploadFutures.add(_uploadSinglePartWithRetry(
          partNumber: pNum,
          initialUrl: url,
          targetFile: targetFile,
        ));
      }

      final results = await Future.wait(uploadFutures);
      if (results.contains(false) || batchFailed) {
        if (_pauseRequested) {
          state = MultipartUploadState.paused;
          _saveCurrentSessionRecord();
          notifyProgress();
          return;
        }
        if (_cancelRequested) {
          return;
        }
        _setError(
            'Part upload failed after multiple retry attempts. You can click Retry to continue.');
        return;
      }

      missingParts.removeWhere((pNum) => completedETags.containsKey(pNum));
    }

    if (_pauseRequested) {
      state = MultipartUploadState.paused;
      _saveCurrentSessionRecord();
      notifyProgress();
      return;
    }

    if (missingParts.isEmpty && !_cancelRequested) {
      await _completeUpload();
    }
  }

  Future<Map<int, String>> _fetchPresignedUrls(List<int> partNumbers) async {
    final payload = {
      'uploadSessionId': uploadSessionId,
      'uploadId': uploadId,
      'key': key,
      'partNumbers': partNumbers,
    };

    final authHdrs = await AuthService.authHeaders();
    final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

    debugPrint('''
========== PRESIGN REQUEST ==========
uploadSessionId: $uploadSessionId
partNumbers: $partNumbers
numberOfPartsRequested: ${partNumbers.length}
URL: ${ApiConstant.multipartPresign}
METHOD: POST
HEADERS: $redactedHdrs
BODY: ${jsonEncode(payload)}
=====================================''');

    final apiHelper = ApiHelper();
    final response =
        await apiHelper.postApiWithBody(ApiConstant.multipartPresign, payload);

    debugPrint('''
========== PRESIGN RESPONSE ==========
status: ${response.statusCode}
BODY: ${response.body}
======================================''');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Presign API returned HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> bodyJson = jsonDecode(response.body);
    final data = bodyJson['data'] as Map<String, dynamic>? ?? bodyJson;
    final urlsRaw = data['urls'] as List<dynamic>? ?? [];

    final Map<int, String> result = {};
    for (final item in urlsRaw) {
      if (item is Map) {
        final pNum = item['partNumber'];
        final url = item['url']?.toString();
        if (pNum != null && url != null && url.isNotEmpty) {
          final parsedNum = int.parse(pNum.toString());
          result[parsedNum] = url;
          debugPrint(
              '[Direct S3 Upload] Mapped Part $parsedNum -> Presigned URL: ${_sanitizeUrl(url)}');
        }
      }
    }

    debugPrint('''
========== PRESIGN MAPPING VERIFICATION ==========
numberOfUrls: ${result.length}
partNumbersReturned: ${result.keys.toList()}
==================================================''');

    return result;
  }

  Future<bool> _uploadSinglePartWithRetry({
    required int partNumber,
    required String initialUrl,
    required html.File targetFile,
  }) async {
    int attempts = 0;
    const maxAttempts = 4;
    String currentUrl = initialUrl;

    while (attempts < maxAttempts && !_pauseRequested && !_cancelRequested) {
      attempts++;
      await GlobalS3ConcurrencyLimiter.acquire();

      try {
        activePartNumbers.add(partNumber);
        final success = await _uploadSinglePartHttp(
          partNumber: partNumber,
          url: currentUrl,
          targetFile: targetFile,
          attempt: attempts,
        );

        if (success) {
          return true;
        }
      } catch (e) {
        debugPrint(
            '[Direct S3 Upload] ⚠️ Part $partNumber attempt $attempts error: $e');
      } finally {
        activePartNumbers.remove(partNumber);
        partBytesInFlight.remove(partNumber);
        GlobalS3ConcurrencyLimiter.release();
      }

      if (_pauseRequested || _cancelRequested) return false;

      // Exponential backoff with jitter
      final backoffMs =
          (pow(2, attempts) * 500 + Random().nextInt(400)).toInt();
      debugPrint(
          '[Direct S3 Upload] 🔄 Retrying Part $partNumber (Attempt ${attempts + 1}/$maxAttempts) after ${backoffMs}ms backoff...');
      await Future.delayed(Duration(milliseconds: backoffMs));

      // Fetch fresh URL for part in case presigned URL expired
      try {
        debugPrint(
            '[Direct S3 Upload] 🔄 Requesting fresh presigned URL for Part $partNumber before retry...');
        final freshUrls = await _fetchPresignedUrls([partNumber]);
        if (freshUrls.containsKey(partNumber)) {
          currentUrl = freshUrls[partNumber]!;
        }
      } catch (_) {}
    }

    return false;
  }

  Future<bool> _uploadSinglePartHttp({
    required int partNumber,
    required String url,
    required html.File targetFile,
    required int attempt,
  }) async {
    final startByte = (partNumber - 1) * partSize;
    final endByte = min(startByte + partSize, fileSize);
    final chunkLength = endByte - startByte;
    final partBlob = targetFile.slice(startByte, endByte);
    final chunkSizeMb = (chunkLength / (1024 * 1024)).toStringAsFixed(2);

    debugPrint('''
========== S3 PART START ==========
partNumber: $partNumber
startByte: $startByte
endByte: $endByte
chunkSize: $chunkLength
chunkSizeMB: $chunkSizeMb MB
attempt: $attempt
activeUploads: ${GlobalS3ConcurrencyLimiter._activeRequests}
==================================''');

    final completer = Completer<bool>();
    final xhr = html.HttpRequest();
    activeXhrs[partNumber] = xhr;
    final stopwatch = Stopwatch()..start();

    // S3 PUT using HttpRequest directly (no generic authorization headers added)
    xhr.open('PUT', url);
    final putMime = targetFile.type.isNotEmpty
        ? targetFile.type
        : 'application/octet-stream';
    xhr.setRequestHeader('Content-Type', putMime);

    int lastLoaded = 0;
    xhr.upload.onProgress.listen((e) {
      if (e.lengthComputable == true && e.loaded != null) {
        final diff = e.loaded! - lastLoaded;
        if (diff > 0) {
          _bytesUploadedSinceStart += diff;
          lastLoaded = e.loaded!;
        }
        partBytesInFlight[partNumber] = e.loaded!;
        notifyProgress();
      }
    });

    xhr.onLoad.listen((_) {
      stopwatch.stop();
      activeXhrs.remove(partNumber);
      final durationMs = stopwatch.elapsedMilliseconds;

      if (xhr.status == 200 || xhr.status == 201 || xhr.status == 204) {
        String? eTag = xhr.getResponseHeader('ETag') ??
            xhr.getResponseHeader('etag') ??
            xhr.getResponseHeader('ETAG');

        if (eTag == null || eTag.trim().isEmpty) {
          final allHeaders = xhr.getAllResponseHeaders();
          final lines = allHeaders.split('\n');
          for (final l in lines) {
            final parts = l.split(':');
            if (parts.length >= 2 && parts[0].trim().toLowerCase() == 'etag') {
              eTag = parts.sublist(1).join(':').trim();
              break;
            }
          }
        }

        if (eTag != null && eTag.trim().isNotEmpty) {
          eTag = _ensureQuotedETag(eTag);
        }

        if (eTag == null || eTag.trim().isEmpty) {
          debugPrint('''
========== S3 PART ERROR ==========
partNumber: $partNumber
statusCode: ${xhr.status}
attempt: $attempt
error: ETag Header Missing (CORS)
responseBody: S3 returned HTTP ${xhr.status} but ETag header was not exposed by CORS. Ensure S3 CORS includes <ExposeHeader>ETag</ExposeHeader>
==================================''');
          completer.complete(false);
          return;
        }

        completedETags[partNumber] = eTag;

        debugPrint('''
========== S3 PART SUCCESS ==========
partNumber: $partNumber
statusCode: ${xhr.status}
etag: $eTag
durationMs: ${durationMs}ms
=====================================''');

        _recalculateConfirmedBytes();
        _saveCurrentSessionRecord();
        notifyProgress();
        completer.complete(true);
      } else {
        debugPrint('''
========== S3 PART ERROR ==========
partNumber: $partNumber
statusCode: ${xhr.status}
attempt: $attempt
error: ${xhr.statusText}
responseBody: ${xhr.responseText}
==================================''');
        completer.complete(false);
      }
    });

    xhr.onError.listen((_) {
      stopwatch.stop();
      activeXhrs.remove(partNumber);
      debugPrint('''
========== S3 PART ERROR ==========
partNumber: $partNumber
statusCode: ${xhr.status}
attempt: $attempt
error: Network / CORS Error
responseBody: ${xhr.responseText}
==================================''');
      completer.complete(false);
    });

    xhr.onAbort.listen((_) {
      stopwatch.stop();
      activeXhrs.remove(partNumber);
      debugPrint(
          '[Direct S3 Upload] ⏹️ [Part $partNumber/$totalParts] S3 PUT aborted.');
      completer.complete(false);
    });

    xhr.send(partBlob);
    return completer.future;
  }

  void _recalculateConfirmedBytes() {
    int total = 0;
    for (final pNum in completedETags.keys) {
      final start = (pNum - 1) * partSize;
      final end = min(start + partSize, fileSize);
      total += (end - start);
    }
    _uploadedBytesConfirmed = total;
  }

  Future<void> _completeUpload() async {
    if (_completingInProgress) return;
    _completingInProgress = true;
    state = MultipartUploadState.completing;
    notifyProgress();

    try {
      final missingList = <int>[];
      for (int p = 1; p <= totalParts; p++) {
        if (!completedETags.containsKey(p)) {
          missingList.add(p);
        }
      }

      if (missingList.isNotEmpty) {
        _setError('Cannot complete upload: parts $missingList are missing.');
        _completingInProgress = false;
        return;
      }

      final partsList = completedETags.entries
          .map((e) => {'partNumber': e.key, 'eTag': _ensureQuotedETag(e.value)})
          .toList();

      final Map<int, String> uniqueMap = {};
      for (final item in partsList) {
        uniqueMap[item['partNumber'] as int] = item['eTag'] as String;
      }

      final sortedParts = uniqueMap.entries
          .map((e) => {'partNumber': e.key, 'eTag': e.value})
          .toList()
        ..sort((a, b) =>
            (a['partNumber'] as int).compareTo(b['partNumber'] as int));

      final payload = {
        'uploadSessionId': uploadSessionId,
        'uploadId': uploadId,
        'key': key,
        'parts': sortedParts,
      };

      final authHdrs = await AuthService.authHeaders();
      final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

      debugPrint('''
========== MULTIPART COMPLETE REQUEST ==========
uploadSessionId: $uploadSessionId
totalParts: $totalParts
completedParts: ${completedETags.length}
allPartsUploaded: true
totalUploadedBytes: $_uploadedBytesConfirmed
totalFileBytes: $fileSize
s3Key: $key
URL: ${ApiConstant.multipartComplete}
METHOD: POST
HEADERS: $redactedHdrs
BODY: ${jsonEncode(payload)}
=============================================== ''');

      final apiHelper = ApiHelper();
      final response = await apiHelper.postApiWithBody(
          ApiConstant.multipartComplete, payload);

      debugPrint('''
========== MULTIPART COMPLETE RESPONSE ==========
HTTP STATUS: ${response.statusCode}
success: ${response.statusCode == 200 || response.statusCode == 201}
message: ${response.body}
status: COMPLETED
s3Key: $key
=============================================== ''');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg = _extractErrorMessage(response.body,
            'Failed to complete multipart upload (${response.statusCode})');
        _setError(msg);
        _completingInProgress = false;
        return;
      }

      try {
        final Map<String, dynamic> bodyJson = jsonDecode(response.body);
        final data = bodyJson['data'] as Map<String, dynamic>? ?? bodyJson;
        final String? extractedUrl = data['videoUrl']?.toString() ??
            data['hlsUrl']?.toString() ??
            bodyJson['videoUrl']?.toString() ??
            bodyJson['hlsUrl']?.toString();
        if (extractedUrl != null && extractedUrl.isNotEmpty) {
          videoUrl = extractedUrl;
        }
      } catch (_) {}

      state = MultipartUploadState.completed;
      debugPrint('''
========== MOVIE UPLOAD SUCCESS ==========
fileName: $fileName
fileSize: $fileSize
totalParts: $totalParts
s3Key: $key
=========================================''');
      MultipartUploadPersistence.removeSession(localTaskId);
      notifyProgress();
    } catch (e) {
      debugPrint('[Direct S3 Upload] ❌ Complete upload exception: $e');
      _setError('Error while completing upload: $e');
    } finally {
      _completingInProgress = false;
    }
  }

  void pause() {
    if (state == MultipartUploadState.uploading) {
      _pauseRequested = true;
      activeXhrs.forEach((_, xhr) {
        try {
          xhr.abort();
        } catch (_) {}
      });
      activeXhrs.clear();
      state = MultipartUploadState.paused;
      _saveCurrentSessionRecord();
      notifyProgress();
    }
  }

  Future<void> abort() async {
    _cancelRequested = true;
    _pauseRequested = true;
    activeXhrs.forEach((_, xhr) {
      try {
        xhr.abort();
      } catch (_) {}
    });
    activeXhrs.clear();

    debugPrint('''
========== MULTIPART ABORT ==========
uploadSessionId: $uploadSessionId
reason: User requested abort
=====================================''');

    if (uploadSessionId != null) {
      try {
        final apiHelper = ApiHelper();
        final url = ApiConstant.multipartAbort(uploadSessionId);
        final authHdrs = await AuthService.authHeaders();
        final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

        debugPrint('''
========== MULTIPART ABORT REQUEST ==========
URL: $url
METHOD: DELETE
HEADERS: $redactedHdrs
BODY: None
===============================================''');

        final response = await apiHelper.deleteApi(url);

        debugPrint('''
========== MULTIPART ABORT RESPONSE ==========
STATUS: ${response.statusCode}
BODY: ${response.body}
=============================================== ''');
      } catch (e) {
        debugPrint('[Direct S3 Upload] ❌ Error sending abort API request: $e');
      }
    }

    state = MultipartUploadState.aborted;
    MultipartUploadPersistence.removeSession(localTaskId);
    notifyProgress();
  }

  void _saveCurrentSessionRecord() {
    if (uploadSessionId == null) return;
    final record = MultipartSessionRecord(
      uploadSessionId: uploadSessionId,
      uploadId: uploadId,
      key: key,
      partSize: partSize,
      totalParts: totalParts,
      contentId: contentId,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      lastModified: lastModified,
      localTaskId: localTaskId,
      status: state.name,
      uploadedETags: Map.from(completedETags),
    );
    MultipartUploadPersistence.saveSession(record);
  }

  void _setError(String msg) {
    errorMessage = msg;
    state = MultipartUploadState.failed;
    _saveCurrentSessionRecord();
    notifyProgress();
  }

  String _extractErrorMessage(String body, String fallback) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final k in ['message', 'error', 'details']) {
          final v = decoded[k]?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return fallback;
  }
}
