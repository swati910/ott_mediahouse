import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
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
  aborting,
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

  bool get isAborting => state == MultipartUploadState.aborting;

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
  String? _lastFailureReason;
  String? get lastFailureReason => _lastFailureReason;
  String videoUrl = '';

  final Map<int, String> completedETags = {};
  final Map<int, int> partBytesInFlight = {};
  final Set<int> activePartNumbers = {};
  final Map<int, html.HttpRequest> activeXhrs = {};

  bool _pauseRequested = false;
  bool _cancelRequested = false;
  bool _completingInProgress = false;
  bool _isAborting = false;
  bool get isAborting => _isAborting;

  /// When true, forces session-based abort (`DELETE /api/video/multipart/{uploadSessionId}`).
  /// By default (false), uses `POST /api/video/multipart/abort` when S3 uploadId and key are available.
  static bool preferSessionIdAbort = false;

  /// When false (default), uploads send PUT directly to the Amazon S3 presigned URL.
  /// When true, rewrites the URL to route through the local CORS dev proxy on port 8089.
  static bool useLocalDevProxy = false;

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
    int inFlightBytes = 0;
    if (state == MultipartUploadState.uploading ||
        state == MultipartUploadState.completing) {
      partBytesInFlight.forEach((_, bytes) {
        inFlightBytes += bytes;
      });
    }

    int currentUploadedBytes = _uploadedBytesConfirmed + inFlightBytes;
    if (fileSize > 0) {
      currentUploadedBytes = min(currentUploadedBytes, fileSize);
    }

    double pct = 0.0;
    if (state == MultipartUploadState.completed) {
      pct = 100.0;
      currentUploadedBytes = fileSize;
    } else if (fileSize > 0) {
      final rawPct = (currentUploadedBytes / fileSize) * 100.0;
      // If parts are not all confirmed by Amazon S3, never display 100%!
      // Cap at 99.0% while upload or completion is in-flight.
      if (completedETags.length < totalParts) {
        pct = min(rawPct, 99.0);
      } else {
        pct = min(rawPct, 99.9);
      }
      pct = pct.clamp(0.0, 99.9);
    }

    // In failed, aborting, or aborted state, in-flight bytes do NOT count.
    if (state == MultipartUploadState.failed ||
        state == MultipartUploadState.aborting ||
        state == MultipartUploadState.aborted) {
      currentUploadedBytes = _uploadedBytesConfirmed;
      pct = fileSize > 0
          ? ((_uploadedBytesConfirmed / fileSize) * 100.0).clamp(0.0, 99.0)
          : 0.0;
    }

    double speed = 0.0;
    int remainingSec = 0;
    if (state == MultipartUploadState.uploading && _uploadStartTime != null) {
      final elapsedSec =
          DateTime.now().difference(_uploadStartTime!).inMilliseconds / 1000.0;
      if (elapsedSec > 0.5 && _bytesUploadedSinceStart > 0) {
        speed = _bytesUploadedSinceStart / elapsedSec;
        final remainingBytes = max(0, fileSize - currentUploadedBytes);
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
[MovieUpload] Part Upload Progress
partNumber: $samplePart
bytesSent: $sampleBytes
partTotalBytes: $samplePartSize
partProgress: ${samplePartPct.toStringAsFixed(1)}%
totalUploadedBytes: $currentUploadedBytes
totalFileBytes: $fileSize
overallProgress: ${pct.toStringAsFixed(1)}%
activeUploads: ${GlobalS3ConcurrencyLimiter._activeRequests}''');
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

      final initiateStopwatch = Stopwatch()..start();
      final initiateStartTime = DateTime.now().toIso8601String();
      debugPrint('''
[MovieUpload] Initiate Request
endpoint: ${ApiConstant.multipartInitiate}
method: POST
startTime: $initiateStartTime
contentId: $contentId
fileName: ${targetFile.name}
fileSize: ${targetFile.size} ($sizeMb MB)
contentType: $cType
headers: $redactedHdrs
payload: ${jsonEncode(payload)}''');

      final apiHelper = ApiHelper();
      final response = await apiHelper.postApiWithBody(
          ApiConstant.multipartInitiate, payload);
      initiateStopwatch.stop();

      debugPrint('''
[MovieUpload] Initiate Response
endpoint: ${ApiConstant.multipartInitiate}
statusCode: ${response.statusCode}
success: ${response.statusCode == 200 || response.statusCode == 201}
durationMs: ${initiateStopwatch.elapsedMilliseconds}ms
body: ${response.body}''');

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
      if (partSize <= 0) {
        // Amazon S3 requires >= 5MB for non-final parts. Default to 10MB chunk size.
        partSize = 10 * 1024 * 1024;
      }

      final serverTotalParts = data['totalParts'] != null
          ? int.parse(data['totalParts'].toString())
          : 0;
      final calculatedParts = (targetFile.size / partSize).ceil();
      totalParts = serverTotalParts > 0 ? serverTotalParts : calculatedParts;
      if (totalParts <= 0) {
        totalParts = 1;
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
        final detail = _lastFailureReason != null ? ': $_lastFailureReason' : '';
        _setError(
            'Part upload failed after multiple retry attempts$detail. You can click Retry to continue.');
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

    final presignStopwatch = Stopwatch()..start();
    final presignStartTime = DateTime.now().toIso8601String();
    debugPrint('''
[MovieUpload] Presign Request
endpoint: ${ApiConstant.multipartPresign}
method: POST
startTime: $presignStartTime
uploadSessionId: $uploadSessionId
uploadId: $uploadId
s3Key: $key
partNumbers: $partNumbers
numberOfPartsRequested: ${partNumbers.length}
headers: $redactedHdrs
payload: ${jsonEncode(payload)}''');

    final apiHelper = ApiHelper();
    final response =
        await apiHelper.postApiWithBody(ApiConstant.multipartPresign, payload);
    presignStopwatch.stop();

    debugPrint('''
[MovieUpload] Presign Response
endpoint: ${ApiConstant.multipartPresign}
statusCode: ${response.statusCode}
success: ${response.statusCode == 200 || response.statusCode == 201}
durationMs: ${presignStopwatch.elapsedMilliseconds}ms
body: ${response.body}''');

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

    final partStartTime = DateTime.now().toIso8601String();
    debugPrint('''
[MovieUpload] Part Upload Started
operation: S3 Presigned Part PUT
endpoint: ${_sanitizeUrl(url)}
method: PUT
uploadSessionId: $uploadSessionId
s3Key: $key
partNumber: $partNumber
totalParts: $totalParts
chunkSize: $chunkLength bytes ($chunkSizeMb MB)
byteRange: $startByte-$endByte of $fileSize
attempt: $attempt
startTime: $partStartTime
activeUploads: ${GlobalS3ConcurrencyLimiter._activeRequests}''');

    final completer = Completer<bool>();
    final xhr = html.HttpRequest();
    activeXhrs[partNumber] = xhr;
    final stopwatch = Stopwatch()..start();

    final isLocalhost = kIsWeb &&
        (html.window.location.hostname == 'localhost' ||
            html.window.location.hostname == '127.0.0.1');

    final origUri = Uri.tryParse(url);
    final origHost = origUri?.host ?? 'unknown';

    String targetUrl = url;
    final bool proxyRewriteDetected = isLocalhost && useLocalDevProxy;
    if (proxyRewriteDetected) {
      targetUrl =
          'http://127.0.0.1:8089/proxy?url=${Uri.encodeComponent(url)}';
    }

    final targetUri = Uri.tryParse(targetUrl);
    final finalHost = targetUri?.host ?? 'unknown';

    debugPrint('''
[MovieUpload] Original Presigned URL Host: $origHost
[MovieUpload] Final Request Host: $finalHost
[MovieUpload] Proxy Rewrite Detected: $proxyRewriteDetected''');

    // S3 PUT using HttpRequest directly (no generic authorization headers added)
    xhr.open('PUT', targetUrl);

    // Only set Content-Type header if the presigned URL's signed headers explicitly require it.
    // For Amazon S3 multipart uploads, chunk parts are raw byte slices where Content-Type is
    // typically unsigned. Setting an unnecessary Content-Type header causes S3 SignatureDoesNotMatch
    // or CORS preflight failures when Content-Type is not in S3's AllowedHeaders.
    final uri = Uri.tryParse(url);
    final signedHeaders = (uri?.queryParameters['X-Amz-SignedHeaders'] ??
            uri?.queryParameters['x-amz-signedheaders'] ??
            '')
        .toLowerCase();
    if (signedHeaders.split(';').contains('content-type')) {
      final putMime = targetFile.type.isNotEmpty
          ? targetFile.type
          : 'application/octet-stream';
      xhr.setRequestHeader('Content-Type', putMime);
    }

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

    xhr.onLoad.listen((_) async {
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

        // Fallback for missing ETag header:
        // When S3 CORS configuration does not include <ExposeHeader>ETag</ExposeHeader>,
        // the browser hides the ETag header from JavaScript. In Amazon S3 multipart uploads,
        // each part's ETag is ALWAYS the hex-encoded MD5 digest of the uploaded chunk data.
        if (eTag == null || eTag.trim().isEmpty) {
          try {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(partBlob);
            await reader.onLoad.first;
            final dynamic rawResult = reader.result;
            Uint8List chunkBytes;
            if (rawResult is ByteBuffer) {
              chunkBytes = Uint8List.view(rawResult);
            } else if (rawResult is Uint8List) {
              chunkBytes = rawResult;
            } else {
              chunkBytes = Uint8List.fromList(List<int>.from(rawResult as dynamic));
            }
            final md5Hex = md5.convert(chunkBytes).toString();
            eTag = '"$md5Hex"';
            debugPrint(
                '[Direct S3 Upload] ℹ️ ETag header not exposed by S3 CORS; computed MD5 ETag locally: $eTag');
          } catch (e) {
            debugPrint('[Direct S3 Upload] ⚠️ Failed to compute chunk MD5: $e');
          }
        }

        // Secondary fallback: query backend status API which uses S3 ListParts
        if (eTag == null || eTag.trim().isEmpty) {
          final reconciled = await _reconcileWithStatusApi();
          if (reconciled && completedETags.containsKey(partNumber)) {
            eTag = completedETags[partNumber];
          }
        }

        if (_cancelRequested ||
            _isAborting ||
            state == MultipartUploadState.aborting ||
            state == MultipartUploadState.aborted) {
          debugPrint(
              '[Direct S3 Upload] Part $partNumber arrived after abort/cancel requested; ignoring.');
          completer.complete(false);
          return;
        }

        if (eTag != null && eTag.trim().isNotEmpty) {
          eTag = _ensureQuotedETag(eTag);
          completedETags[partNumber] = eTag;

          debugPrint('''
[MovieUpload] Part Upload Success
operation: S3 Presigned Part PUT
uploadSessionId: $uploadSessionId
s3Key: $key
partNumber: $partNumber
totalParts: $totalParts
statusCode: ${xhr.status}
success: true
eTagPresent: true
eTag: $eTag
uploadedPartNumber: $partNumber
durationMs: ${durationMs}ms
uploadedBytesConfirmed: $_uploadedBytesConfirmed of $fileSize
completedParts: ${completedETags.length} of $totalParts''');

          _recalculateConfirmedBytes();
          _saveCurrentSessionRecord();
          notifyProgress();
          completer.complete(true);
        } else {
          _lastFailureReason =
              'S3 uploaded part successfully but ETag header was unreadable';
          debugPrint('''
[MovieUpload] Part Upload Failed
operation: S3 Presigned Part PUT
uploadSessionId: $uploadSessionId
s3Key: $key
partNumber: $partNumber
totalParts: $totalParts
statusCode: ${xhr.status}
attempt: $attempt
errorType: Missing ETag
errorMessage: $_lastFailureReason
durationMs: ${stopwatch.elapsedMilliseconds}ms''');
          completer.complete(false);
        }
      } else {
        _lastFailureReason =
            'S3 returned HTTP ${xhr.status} (${xhr.statusText ?? 'Error'})';
        debugPrint('''
[MovieUpload] Part Upload Failed
operation: S3 Presigned Part PUT
uploadSessionId: $uploadSessionId
s3Key: $key
partNumber: $partNumber
totalParts: $totalParts
statusCode: ${xhr.status}
attempt: $attempt
errorType: HTTP Error
errorMessage: $_lastFailureReason
responseBody: ${xhr.responseText}
durationMs: ${stopwatch.elapsedMilliseconds}ms''');
        completer.complete(false);
      }
    });

    xhr.onError.listen((_) {
      stopwatch.stop();
      activeXhrs.remove(partNumber);
      activePartNumbers.remove(partNumber);
      partBytesInFlight.remove(partNumber);
      _lastFailureReason =
          'Network connection interrupted or S3 CORS restriction';
      debugPrint('''
[MovieUpload] Part Upload Failed
operation: S3 Presigned Part PUT
uploadSessionId: $uploadSessionId
s3Key: $key
partNumber: $partNumber
totalParts: $totalParts
statusCode: ${xhr.status}
attempt: $attempt
targetUrl: ${_sanitizeUrl(targetUrl)}
errorType: Network / CORS Error
errorMessage: $_lastFailureReason
responseBody: ${xhr.responseText}
durationMs: ${stopwatch.elapsedMilliseconds}ms''');
      completer.complete(false);
    });

    xhr.onAbort.listen((_) {
      stopwatch.stop();
      activeXhrs.remove(partNumber);
      activePartNumbers.remove(partNumber);
      partBytesInFlight.remove(partNumber);
      _lastFailureReason = 'Upload paused or aborted';
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
    if (_cancelRequested ||
        _isAborting ||
        state == MultipartUploadState.aborting ||
        state == MultipartUploadState.aborted) {
      debugPrint(
          '[Direct S3 Upload] Abort/cancel requested; skipping completeMultipartUpload.');
      return;
    }
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

      final completeStopwatch = Stopwatch()..start();
      final completeStartTime = DateTime.now().toIso8601String();
      debugPrint('''
[MovieUpload] Complete Request
endpoint: ${ApiConstant.multipartComplete}
method: POST
startTime: $completeStartTime
uploadSessionId: $uploadSessionId
uploadId: $uploadId
s3Key: $key
totalParts: $totalParts
completedParts: ${completedETags.length}
totalUploadedBytes: $_uploadedBytesConfirmed
totalFileBytes: $fileSize
headers: $redactedHdrs
payload: ${jsonEncode(payload)}''');

      final apiHelper = ApiHelper();
      final response = await apiHelper.postApiWithBody(
          ApiConstant.multipartComplete, payload);
      completeStopwatch.stop();

      debugPrint('''
[MovieUpload] Complete Response
endpoint: ${ApiConstant.multipartComplete}
statusCode: ${response.statusCode}
success: ${response.statusCode == 200 || response.statusCode == 201}
durationMs: ${completeStopwatch.elapsedMilliseconds}ms
uploadSessionId: $uploadSessionId
s3Key: $key
videoUrl: $videoUrl
body: ${response.body}''');

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

  Future<bool> abort() async {
    if (_isAborting) {
      debugPrint(
          '[MultipartUpload] Cancellation already in progress for taskId: $localTaskId');
      return true;
    }
    _isAborting = true;
    _cancelRequested = true;
    _pauseRequested = true;
    state = MultipartUploadState.aborting;

    // 1. Stop active browser requests and prevent new parts from starting
    final stoppedPartsCount = activeXhrs.length;
    activeXhrs.forEach((_, xhr) {
      try {
        xhr.abort();
      } catch (_) {}
    });
    activeXhrs.clear();
    activePartNumbers.clear();
    partBytesInFlight.clear();
    notifyProgress();

    // 2. Required diagnostic logging (Section 9)
    debugPrint(
        '[MultipartUpload] Cancellation Requested: taskId=$localTaskId, fileName=$fileName, completedParts=${completedETags.length}/$totalParts');
    debugPrint('[MultipartUpload] Upload Session ID: ${uploadSessionId ?? 'none'}');
    debugPrint('[MultipartUpload] Active Parts Stopped: $stoppedPartsCount');

    // If no backend session was initiated, simply clean up local state
    if (uploadSessionId == null) {
      debugPrint(
          '[MultipartUpload] No active backend uploadSessionId; cancelling local state only.');
      state = MultipartUploadState.aborted;
      _uploadedBytesConfirmed = 0;
      completedETags.clear();
      MultipartUploadPersistence.removeSession(localTaskId);
      _isAborting = false;
      notifyProgress();
      return true;
    }

    // 3. Determine which Abort API to use (Section 4)
    // Use POST /api/video/multipart/abort when S3 uploadId and key are present for full cleanup
    // Use DELETE /api/video/multipart/{uploadSessionId} when identifying from session ID alone
    final bool useBodyApi = !preferSessionIdAbort &&
        uploadId.isNotEmpty &&
        key.isNotEmpty;

    final String selectedApi;
    final String endpoint;
    final String method;
    Map<String, dynamic>? requestBody;

    if (useBodyApi) {
      endpoint = ApiConstant.multipartAbortWithBody;
      method = 'POST';
      requestBody = {
        'uploadId': uploadId,
        'key': key,
        'uploadSessionId': uploadSessionId,
      };
      selectedApi = 'POST $endpoint (Body with uploadId, key, uploadSessionId)';
    } else {
      endpoint = ApiConstant.multipartAbort(uploadSessionId);
      method = 'DELETE';
      selectedApi = 'DELETE $endpoint (Session ID alone)';
    }

    debugPrint('[MultipartUpload] Abort API Selected: $selectedApi');

    bool success = false;
    String? failureReason;

    try {
      final apiHelper = ApiHelper();
      final authHdrs = await AuthService.authHeaders();
      final redactedHdrs = _formatHeadersWithAuthRedacted(authHdrs);

      final abortStopwatch = Stopwatch()..start();
      final abortStartTime = DateTime.now().toIso8601String();

      debugPrint('''
[MultipartUpload] Abort Request
endpoint: $endpoint
method: $method
startTime: $abortStartTime
uploadSessionId: $uploadSessionId
uploadId: $uploadId
s3Key: $key
payload: ${requestBody != null ? jsonEncode(requestBody) : 'none'}
headers: $redactedHdrs''');

      dynamic response;
      if (method == 'POST') {
        response = await apiHelper.postApiWithBody(endpoint, requestBody!);
      } else {
        response = await apiHelper.deleteApi(endpoint);
      }
      abortStopwatch.stop();

      final statusCode = response.statusCode as int? ?? 0;
      final responseBody = response.body?.toString() ?? '';

      debugPrint('''
[MultipartUpload] Abort Response
endpoint: $endpoint
method: $method
statusCode: $statusCode
durationMs: ${abortStopwatch.elapsedMilliseconds}ms
body: $responseBody''');

      // 4. Handle response status codes (Section 8)
      if (statusCode >= 200 && statusCode < 300) {
        success = true;
      } else if (statusCode == 404) {
        // Session not found - handled gracefully as already cleaned up or expired
        debugPrint(
            '[MultipartUpload] Session $uploadSessionId not found on server; treated as successfully cleaned up.');
        success = true;
      } else if (statusCode == 400 || statusCode == 409 || statusCode == 410) {
        final lowerBody = responseBody.toLowerCase();
        if (lowerBody.contains('already aborted') ||
            lowerBody.contains('not found') ||
            lowerBody.contains('expired') ||
            lowerBody.contains('already cancelled') ||
            lowerBody.contains('invalid session')) {
          debugPrint(
              '[MultipartUpload] Session $uploadSessionId already aborted/expired on server; treated as successfully cleaned up.');
          success = true;
        } else {
          failureReason = 'Server rejected abort request: $responseBody';
          debugPrint('[MultipartUpload] ⚠️ Abort failed: $failureReason');
        }
      } else if (statusCode == 401 || statusCode == 403) {
        failureReason = 'Authentication failed while cancelling upload.';
        debugPrint('[MultipartUpload] ⚠️ Abort unauthorized: HTTP $statusCode');
      } else {
        failureReason =
            'Backend returned HTTP $statusCode while cancelling upload.';
        debugPrint('[MultipartUpload] ⚠️ Abort server error: HTTP $statusCode');
      }
    } catch (e) {
      failureReason =
          'Network or connection error while cancelling upload: $e';
      debugPrint('[MultipartUpload] ❌ Exception during abort request: $e');
    }

    if (success) {
      // 5. Clear local upload state only after abort has been handled (Section 3 & 7)
      state = MultipartUploadState.aborted;
      errorMessage = null;
      _uploadedBytesConfirmed = 0;
      completedETags.clear();
      MultipartUploadPersistence.removeSession(localTaskId);
    } else {
      // Retain session information to allow retry cleanup or recover safely (Section 7)
      state = MultipartUploadState.failed;
      errorMessage =
          failureReason ?? 'Unable to cancel the upload. Please try again.';
      _saveCurrentSessionRecord();
    }

    _isAborting = false;
    notifyProgress();
    return success;
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
    partBytesInFlight.clear();
    activePartNumbers.clear();
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
