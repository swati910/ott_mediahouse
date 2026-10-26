import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:media_house/app/core/auth/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/utils/image_validation_service.dart';
import 'package:media_house/app/provider/shorts_provider.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../../../widget/multipart_upload_progress_widget.dart';

import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../../data/models/response/video_upload_response.dart';

class CreateShortPartsDialog extends StatefulWidget {
  final int shortId;
  final int totalParts;
  final int existingPartCount;
  final int defaultCoins;
  final String masterTitle;
  final String masterDescription;

  const CreateShortPartsDialog({
    super.key,
    required this.shortId,
    required this.totalParts,
    required this.existingPartCount,
    required this.defaultCoins,
    required this.masterTitle,
    required this.masterDescription,
  });

  @override
  State<CreateShortPartsDialog> createState() => _CreateShortPartsDialogState();
}

class _CreateShortPartsDialogState extends State<CreateShortPartsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<_ShortPartDraft> _partDrafts;
  bool _isSubmitting = false;
  String? _lastUploadError;

  int get _remainingParts => widget.totalParts - widget.existingPartCount;

  @override
  void initState() {
    super.initState();
    _partDrafts = List<_ShortPartDraft>.generate(
      _remainingParts > 0 ? _remainingParts : 0,
      (index) => _ShortPartDraft(
        partNumber: widget.existingPartCount + index + 1,
        title: widget.masterTitle,
        description: widget.masterDescription,
        coins: widget.defaultCoins.toString(),
      ),
    );
  }

  @override
  void dispose() {
    for (final draft in _partDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (file.path == null || file.path!.isEmpty) return null;
    return io.File(file.path!).readAsBytes();
  }

  Future<_VideoUploadResult?> _uploadVideoFile(PlatformFile file) async {
    try {
      _lastUploadError = null;
      final bytes = await _resolveFileBytes(file);
      if (bytes == null) {
        _lastUploadError = 'Could not read selected video file.';
        return null;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadVideoMetadata),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (!_isUploadSuccessStatus(response.statusCode)) {
        _lastUploadError = _uploadErrorMessage(response.statusCode, body);
        debugPrint("Short part video upload failed -> "
            "${response.statusCode}: $body");
        return null;
      }
      final uploadedUrl = _extractUploadedVideoUrl(body);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        _lastUploadError = 'Upload completed but video URL was missing.';
        debugPrint("Short part video upload URL missing -> $body");
        return null;
      }
      return _VideoUploadResult(
        url: uploadedUrl,
        durationSec: _extractUploadedVideoDuration(body),
      );
    } catch (error) {
      _lastUploadError = error.toString();
      return null;
    }
  }

  Future<_VideoUploadResult?> _uploadVideoWebFile(html.File file) async {
    _lastUploadError = null;
    final completer = Completer<_VideoUploadResult?>();
    final xhr = html.HttpRequest();
    final formData = html.FormData()..appendBlob('file', file, file.name);

    xhr.onLoad.listen((_) {
      final body = xhr.responseText ?? '';
      if (!_isUploadSuccessStatus(xhr.status ?? 0)) {
        _lastUploadError = _uploadErrorMessage(xhr.status ?? 0, body);
        debugPrint("Short part web video upload failed -> "
            "${xhr.status}: $body");
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      try {
        final uploadedUrl = _extractUploadedVideoUrl(body);
        if (uploadedUrl == null || uploadedUrl.isEmpty) {
          _lastUploadError = 'Upload completed but video URL was missing.';
          debugPrint("Short part web video upload URL missing -> $body");
          completer.complete(null);
          return;
        }
        completer.complete(
          _VideoUploadResult(
            url: uploadedUrl,
            durationSec: _extractUploadedVideoDuration(body),
          ),
        );
      } catch (error) {
        _lastUploadError = error.toString();
        completer.complete(null);
      }
    });

    xhr.onError.listen((_) {
      _lastUploadError = 'Network error while uploading video.';
      if (!completer.isCompleted) completer.complete(null);
    });

    xhr.open('POST', ApiConstant.uploadVideoMetadata);
    final headers = await AuthService.authHeaders(includeJson: false);
    headers.forEach(xhr.setRequestHeader);
    xhr.send(formData);
    return completer.future;
  }

  bool _isUploadSuccessStatus(int statusCode) {
    return statusCode == 200 || statusCode == 201 || statusCode == 202;
  }

  String? _extractUploadedVideoUrl(String body) {
    final decoded = jsonDecode(body);
    if (decoded is String) return decoded.trim();
    if (decoded is! Map<String, dynamic>) return null;

    final directUrl = _firstUrlFromMap(decoded);
    if (directUrl != null) return directUrl;

    final data = decoded['data'];
    if (data is String) return data.trim();
    if (data is Map<String, dynamic>) {
      final dataUrl = _firstUrlFromMap(data);
      if (dataUrl != null) return dataUrl;

      final parsed = VideoUploadResponse.fromJson(decoded);
      return parsed.data?.fullUrl?.trim();
    }

    return null;
  }

  int _extractUploadedVideoDuration(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        final value = data is Map ? data['duration'] : decoded['duration'];
        if (value is int) return value;
        if (value is num) return value.round();
        if (value is String) return int.tryParse(value) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  String? _firstUrlFromMap(Map<String, dynamic> map) {
    const keys = ['videoUrl', 'fileUrl', 'url', 'secureUrl', 'path'];
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _uploadErrorMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return 'Upload failed ($statusCode): $message';
        }
      }
    } catch (_) {}
    return 'Upload failed with status $statusCode.';
  }

  Future<_ImageUploadResult?> _uploadImageFile(PlatformFile file) async {
    try {
      final bytes = await _resolveFileBytes(file);
      if (bytes == null) return null;
      final validation = await ImageValidationService.validateBytes(
        bytes: bytes,
        fileName: file.name,
        sizeInBytes: file.size,
        type: ImageValidationType.thumbnail,
      );
      if (!validation.isValid) {
        _lastUploadError = validation.message;
        return null;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadContentImg),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) return null;
      final parsed = ContentImageUploadResponse.fromJson(jsonDecode(body));
      final url = parsed.data?.fileUrl?.trim();
      if (url == null || url.isEmpty) return null;
      return _ImageUploadResult(url: url, preview: bytes);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadAudioFile(PlatformFile file) async {
    try {
      _lastUploadError = null;
      final bytes = await _resolveFileBytes(file);
      if (bytes == null) {
        _lastUploadError = 'Could not read selected audio file.';
        return null;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadAudioMetadata),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (!_isUploadSuccessStatus(response.statusCode)) {
        _lastUploadError = _uploadErrorMessage(response.statusCode, body);
        return null;
      }
      final decoded = jsonDecode(body);
      final data = decoded is Map ? decoded['data'] : null;
      final url = data is Map ? data['fullUrl']?.toString().trim() : null;
      if (url == null || url.isEmpty) {
        _lastUploadError = 'Upload completed but audio URL was missing.';
        return null;
      }
      return url;
    } catch (error) {
      _lastUploadError = error.toString();
      return null;
    }
  }

  Future<String?> _uploadSubtitleFile(PlatformFile file) async {
    try {
      _lastUploadError = null;
      final bytes = await _resolveFileBytes(file);
      if (bytes == null) {
        _lastUploadError = 'Could not read selected subtitle file.';
        return null;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadSubtitle),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (!_isUploadSuccessStatus(response.statusCode)) {
        _lastUploadError = _uploadErrorMessage(response.statusCode, body);
        return null;
      }
      final decoded = jsonDecode(body);
      final data = decoded is Map ? decoded['data'] : null;
      final url = data is Map ? data['fileUrl']?.toString().trim() : null;
      if (url == null || url.isEmpty) {
        _lastUploadError = 'Upload completed but subtitle URL was missing.';
        return null;
      }
      return url;
    } catch (error) {
      _lastUploadError = error.toString();
      return null;
    }
  }

  Future<void> _pickVideo(_ShortPartDraft draft) async {
    if (_isSubmitting || draft.isUploadingVideo) return;
    if (kIsWeb) {
      await _pickVideoWeb(draft);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      draft.isUploadingVideo = true;
      draft.videoFileName = file.name;
    });
    final upload = await _uploadVideoFile(file);
    if (!mounted) return;
    setState(() {
      draft.isUploadingVideo = false;
      draft.videoUrl = upload?.url;
      draft.durationSec = upload?.durationSec ?? 0;
    });
    if (upload == null) {
      CustomToast.show(
        context,
        _lastUploadError ?? 'Failed to upload ${file.name}',
        isSuccess: false,
      );
    }
  }

  Future<void> _pickVideoWeb(_ShortPartDraft draft) async {
    final input = html.FileUploadInputElement()..accept = 'video/*';
    input.click();
    await input.onChange.first;

    final file = input.files?.first;
    if (file == null) return;

    setState(() {
      draft.isUploadingVideo = true;
      draft.videoFileName = file.name;
    });

    final upload = await _uploadVideoWebFile(file);
    if (!mounted) return;

    setState(() {
      draft.isUploadingVideo = false;
      draft.videoUrl = upload?.url;
      draft.durationSec = upload?.durationSec ?? 0;
    });

    if (upload == null) {
      CustomToast.show(
        context,
        _lastUploadError ?? 'Failed to upload ${file.name}',
        isSuccess: false,
      );
    }
  }

  Future<void> _pickThumbnail(_ShortPartDraft draft) async {
    if (_isSubmitting || draft.isUploadingThumb) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => draft.isUploadingThumb = true);
    final upload = await _uploadImageFile(file);
    if (!mounted) return;
    setState(() {
      draft.isUploadingThumb = false;
      if (upload != null) {
        draft.thumbnailUrl = upload.url;
        draft.thumbnailPreview = upload.preview;
      }
    });
    if (upload == null) {
      CustomToast.show(
        context,
        _lastUploadError ?? 'Failed to upload thumbnail',
        isSuccess: false,
      );
    }
  }

  Future<void> _pickAudio(_ShortPartDraft draft) async {
    if (_isSubmitting || draft.isUploadingAudio) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'aac', 'm4a'],
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      draft.isUploadingAudio = true;
      draft.audioFileName = file.name;
    });
    final url = await _uploadAudioFile(file);
    if (!mounted) return;
    setState(() {
      draft.isUploadingAudio = false;
      draft.audioFileUrl = url;
    });
    if (url == null) {
      CustomToast.show(
        context,
        _lastUploadError ?? 'Failed to upload ${file.name}',
        isSuccess: false,
      );
    }
  }

  Future<void> _pickSubtitle(_ShortPartDraft draft) async {
    if (_isSubmitting || draft.isUploadingSubtitle) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt'],
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      draft.isUploadingSubtitle = true;
      draft.subtitleFileName = file.name;
    });
    final url = await _uploadSubtitleFile(file);
    if (!mounted) return;
    setState(() {
      draft.isUploadingSubtitle = false;
      draft.subtitleFileUrl = url;
    });
    if (url == null) {
      CustomToast.show(
        context,
        _lastUploadError ?? 'Failed to upload ${file.name}',
        isSuccess: false,
      );
    }
  }

  Future<void> _submit() async {
    if (_remainingParts <= 0) {
      Navigator.of(context).pop(true);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final missingVideos = _partDrafts.any(
      (draft) => draft.videoUrl == null || draft.videoUrl!.trim().isEmpty,
    );
    if (missingVideos) {
      CustomToast.show(
        context,
        'Upload video for every remaining short part.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<ShortProvider>();

    try {
      for (final draft in _partDrafts) {
        final body = {
          'audioFileUrl': draft.audioFileUrl?.trim() ?? '',
          'coins':
              int.tryParse(draft.coinsCtrl.text.trim()) ?? widget.defaultCoins,
          'description': draft.descCtrl.text.trim().isNotEmpty
              ? draft.descCtrl.text.trim()
              : widget.masterDescription,
          'durationSec': draft.durationSec,
          'id': 0,
          'isFreePreview': draft.isFreePreview,
          'likes': 0,
          'partNumber': draft.partNumber,
          'shortId': widget.shortId,
          'subtitleFileUrl': draft.subtitleFileUrl?.trim() ?? '',
          'thumbnail': draft.thumbnailUrl?.trim().isNotEmpty == true
              ? draft.thumbnailUrl!.trim()
              : '',
          'title': draft.titleCtrl.text.trim().isNotEmpty
              ? draft.titleCtrl.text.trim()
              : widget.masterTitle,
          'videoUrl': draft.videoUrl!.trim(),
          'views': 0,
        };

        final success = await provider.createShortPart(body);
        if (!success) {
          throw Exception('Failed to create part ${draft.partNumber}');
        }
      }

      if (!mounted) return;
      CustomToast.show(context, 'Short parts added successfully.',
          isSuccess: true);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      CustomToast.show(context, error.toString(), isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return WillPopScope(
      onWillPop: () async => !_isSubmitting,
      child: Container(
        width: size.width > 900 ? 920 : size.width * 0.94,
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: _remainingParts <= 0
                  ? _buildNoPendingParts(theme)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMasterSection(theme),
                            const SizedBox(height: 18),
                            _buildPartsSection(theme),
                          ],
                        ),
                      ),
                    ),
            ),
            _buildFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.28)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Short Parts',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _remainingParts > 0
                      ? 'Upload the remaining $_remainingParts part(s) for this short master.'
                      : 'All configured short parts are already uploaded.',
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: theme.canvasColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPendingParts(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'All parts are already uploaded for this short.',
          style: TextStyle(
            color: theme.canvasColor,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMasterSection(ThemeData theme) {
    return _sectionCard(
      theme,
      title: 'Short Master',
      subtitle:
          'These master values are used as defaults for each part title and description.',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _infoTile(theme, 'Master Title', widget.masterTitle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile(
                  theme,
                  'Parts',
                  '${widget.existingPartCount} of ${widget.totalParts} uploaded',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoTile(
            theme,
            'Master Description',
            widget.masterDescription.isEmpty
                ? 'No description available'
                : widget.masterDescription,
          ),
        ],
      ),
    );
  }

  Widget _buildPartsSection(ThemeData theme) {
    return _sectionCard(
      theme,
      title: 'Short Parts Upload Section',
      subtitle:
          'Every pending part needs a video. Title and description are prefilled from Short Master and can still be edited.',
      child: Column(
        children: _partDrafts
            .map(
              (draft) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildPartCard(theme, draft),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPartCard(ThemeData theme, _ShortPartDraft draft) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Part ${draft.partNumber}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          _uploadRow(
            theme,
            title: 'Part Video Upload',
            statusText: draft.videoUrl?.isNotEmpty == true
                ? (draft.videoFileName ?? 'Video uploaded')
                : 'No video uploaded yet',
            uploading: draft.isUploadingVideo,
            uploaded: draft.videoUrl?.isNotEmpty == true,
            onTap: () => _pickVideo(draft),
          ),
          Consumer<ShortProvider>(
            builder: (context, provider, _) {
              final taskId = 'part_${draft.partNumber}';
              final info = provider.getPartProgressInfo(taskId);
              if (info == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: MultipartUploadProgressWidget(
                  info: info,
                  onPause: () => provider.pausePartMultipartUpload(taskId),
                  onResume: () => provider.resumePartMultipartUpload(taskId),
                  onRetry: () => provider.retryPartMultipartUpload(taskId),
                  onAbort: () => provider.abortPartMultipartUpload(taskId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _uploadRow(
            theme,
            title: 'Thumbnail Upload',
            statusText: draft.thumbnailUrl?.isNotEmpty == true
                ? 'Thumbnail uploaded'
                : 'Optional thumbnail',
            uploading: draft.isUploadingThumb,
            uploaded: draft.thumbnailUrl?.isNotEmpty == true,
            onTap: () => _pickThumbnail(draft),
            preview: draft.thumbnailPreview,
          ),
          const SizedBox(height: 12),
          _uploadRow(
            theme,
            title: 'Audio Upload',
            statusText: draft.audioFileUrl?.isNotEmpty == true
                ? (draft.audioFileName ?? 'Audio uploaded')
                : 'Optional audio file',
            uploading: draft.isUploadingAudio,
            uploaded: draft.audioFileUrl?.isNotEmpty == true,
            onTap: () => _pickAudio(draft),
            icon: Icons.audiotrack_outlined,
          ),
          const SizedBox(height: 12),
          _uploadRow(
            theme,
            title: 'Subtitle Upload',
            statusText: draft.subtitleFileUrl?.isNotEmpty == true
                ? (draft.subtitleFileName ?? 'Subtitle uploaded')
                : 'Optional subtitle file',
            uploading: draft.isUploadingSubtitle,
            uploaded: draft.subtitleFileUrl?.isNotEmpty == true,
            onTap: () => _pickSubtitle(draft),
            icon: Icons.subtitles_outlined,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Free Preview',
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: draft.isFreePreview,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => draft.isFreePreview = value),
          ),
        ],
      ),
    );
  }

  Widget _uploadRow(
    ThemeData theme, {
    required String title,
    required String statusText,
    required bool uploading,
    required bool uploaded,
    required VoidCallback onTap,
    Uint8List? preview,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (preview != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                preview,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            Icon(
              uploaded
                  ? Icons.check_circle
                  : (icon ?? Icons.upload_file_rounded),
              color: uploaded ? const Color(0xFF0F9D58) : theme.primaryColor,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  uploading ? 'Uploading...' : statusText,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _isSubmitting || uploading ? null : onTap,
            child: Text(uploaded ? 'Replace' : 'Upload'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.canvasColor.withValues(alpha: 0.68),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(ThemeData theme, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.28)),
        color: theme.cardColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.canvasColor.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: theme.canvasColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    ThemeData theme,
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.canvasColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.canvasColor.withValues(alpha: 0.7)),
        filled: true,
        fillColor: theme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.28)),
        ),
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _isSubmitting || _remainingParts <= 0 ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _isSubmitting ? 'Submitting...' : 'Submit Short Parts',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortPartDraft {
  _ShortPartDraft({
    required this.partNumber,
    required String title,
    required String description,
    required String coins,
  })  : titleCtrl = TextEditingController(text: title),
        descCtrl = TextEditingController(text: description),
        coinsCtrl = TextEditingController(text: coins);

  final int partNumber;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final TextEditingController coinsCtrl;
  String? videoUrl;
  String? videoFileName;
  int durationSec = 0;
  String? audioFileUrl;
  String? audioFileName;
  String? subtitleFileUrl;
  String? subtitleFileName;
  String? thumbnailUrl;
  Uint8List? thumbnailPreview;
  bool isUploadingVideo = false;
  bool isUploadingThumb = false;
  bool isUploadingAudio = false;
  bool isUploadingSubtitle = false;
  bool isFreePreview = false;

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    coinsCtrl.dispose();
  }
}

class _ImageUploadResult {
  const _ImageUploadResult({
    required this.url,
    required this.preview,
  });

  final String url;
  final Uint8List preview;
}

class _VideoUploadResult {
  const _VideoUploadResult({
    required this.url,
    required this.durationSec,
  });

  final String url;
  final int durationSec;
}
