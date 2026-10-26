import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_house/app/core/auth/auth_service.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/network/api_helper.dart';
import 'package:media_house/app/core/utils/image_validation_service.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/provider/shorts_provider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:media_house/app/widget/show_toast.dart';
import 'package:provider/provider.dart';

import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../../data/models/response/video_upload_response.dart';

enum ShortUploadMode { bulk, individual }

class ShortUploadWorkflowDialog extends StatefulWidget {
  const ShortUploadWorkflowDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.all(24),
        backgroundColor: Colors.transparent,
        child: ShortUploadWorkflowDialog(),
      ),
    );
  }

  @override
  State<ShortUploadWorkflowDialog> createState() =>
      _ShortUploadWorkflowDialogState();
}

class _ShortUploadWorkflowDialogState extends State<ShortUploadWorkflowDialog> {
  final _individualFormKey = GlobalKey<FormState>();
  final _masterTitleCtrl = TextEditingController();
  final _masterDescCtrl = TextEditingController();
  final _partsCountCtrl = TextEditingController(text: '1');

  ShortUploadMode _mode = ShortUploadMode.bulk;
  bool _isSubmitting = false;
  bool _isPickingBulkVideos = false;
  bool _isUploadingMasterThumb = false;
  String? _lastUploadError;
  Uint8List? _masterThumbPreview;
  String? _masterThumbUrl;
  List<_BulkShortEntry> _bulkEntries = <_BulkShortEntry>[];
  List<_PartDraft> _partDrafts = <_PartDraft>[_PartDraft(1)];

  @override
  void initState() {
    super.initState();
    _masterTitleCtrl.addListener(_syncMasterTitle);
    _masterDescCtrl.addListener(_syncMasterDescription);
  }

  @override
  void dispose() {
    _masterTitleCtrl.dispose();
    _masterDescCtrl.dispose();
    _partsCountCtrl.dispose();
    for (final entry in _bulkEntries) {
      entry.dispose();
    }
    for (final draft in _partDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _syncMasterTitle() {
    final value = _masterTitleCtrl.text;
    for (final part in _partDrafts) {
      if (part.titleIsInherited) {
        part.setTitle(value);
      }
    }
  }

  void _syncMasterDescription() {
    final value = _masterDescCtrl.text;
    for (final part in _partDrafts) {
      if (part.descriptionIsInherited) {
        part.setDescription(value);
      }
    }
  }

  Future<void> _pickBulkVideos() async {
    if (_isPickingBulkVideos || _isSubmitting) return;
    setState(() => _isPickingBulkVideos = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      for (final file in result.files) {
        final title = _fileBaseName(file.name);
        final entry = _BulkShortEntry(title: title, description: title);
        setState(() => _bulkEntries.add(entry));
        await _uploadBulkVideo(entry, file);
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingBulkVideos = false);
      }
    }
  }

  Future<void> _uploadBulkVideo(
      _BulkShortEntry entry, PlatformFile file) async {
    setState(() {
      entry.isUploadingVideo = true;
      entry.videoFileName = file.name;
    });
    final url = await _uploadVideoFile(file);
    if (!mounted) return;
    setState(() {
      entry.isUploadingVideo = false;
      if (url != null) {
        entry.videoUrl = url;
      }
    });
    if (url == null) {
      CustomToast.show(context, 'Failed to upload ${file.name}',
          isSuccess: false);
    }
  }

  Future<void> _pickBulkThumbnail(_BulkShortEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => entry.isUploadingThumb = true);
    final upload = await _uploadImageFile(file);
    if (!mounted) return;
    setState(() {
      entry.isUploadingThumb = false;
      if (upload != null) {
        entry.thumbnailUrl = upload.url;
        entry.thumbnailPreview = upload.preview;
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

  Future<void> _pickMasterThumbnail() async {
    setState(() => _isUploadingMasterThumb = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      final file = result?.files.single;
      if (file == null) return;
      final upload = await _uploadImageFile(file);
      if (!mounted) return;
      if (upload != null) {
        setState(() {
          _masterThumbUrl = upload.url;
          _masterThumbPreview = upload.preview;
        });
      } else {
        CustomToast.show(
          context,
          _lastUploadError ?? 'Failed to upload thumbnail',
          isSuccess: false,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingMasterThumb = false);
      }
    }
  }

  Future<void> _pickPartVideo(_PartDraft part) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() {
      part.isUploadingVideo = true;
      part.videoFileName = file.name;
    });
    final url = await _uploadVideoFile(file);
    if (!mounted) return;
    setState(() {
      part.isUploadingVideo = false;
      if (url != null) {
        part.videoUrl = url;
      }
    });
  }

  Future<void> _pickPartThumbnail(_PartDraft part) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null) return;
    setState(() => part.isUploadingThumb = true);
    final upload = await _uploadImageFile(file);
    if (!mounted) return;
    setState(() {
      part.isUploadingThumb = false;
      if (upload != null) {
        part.thumbnailUrl = upload.url;
        part.thumbnailPreview = upload.preview;
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

  Future<String?> _uploadVideoFile(PlatformFile file) async {
    try {
      final bytes = await _resolveFileBytes(file);
      if (bytes == null) return null;
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
        debugPrint("Short video upload failed -> "
            "${response.statusCode}: $body");
        return null;
      }
      final uploadedUrl = _extractUploadedVideoUrl(body);
      if (uploadedUrl == null || uploadedUrl.isEmpty) {
        debugPrint("Short video upload URL missing -> $body");
        return null;
      }
      return uploadedUrl;
    } catch (_) {
      return null;
    }
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

  String? _firstUrlFromMap(Map<String, dynamic> map) {
    const keys = ['videoUrl', 'fileUrl', 'url', 'secureUrl', 'path'];
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
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

  Future<Uint8List?> _resolveFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (file.path == null || file.path!.isEmpty) return null;
    return io.File(file.path!).readAsBytes();
  }

  String _fileBaseName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  void _syncPartCount() {
    final count = int.tryParse(_partsCountCtrl.text.trim()) ?? 0;
    if (count <= 0) return;
    if (count == _partDrafts.length) return;
    if (count > _partDrafts.length) {
      final currentTitle = _masterTitleCtrl.text.trim();
      final currentDesc = _masterDescCtrl.text.trim();
      setState(() {
        for (var i = _partDrafts.length; i < count; i++) {
          final part = _PartDraft(i + 1);
          part.setTitle(currentTitle);
          part.setDescription(currentDesc);
          _partDrafts.add(part);
        }
      });
      return;
    }
    setState(() {
      while (_partDrafts.length > count) {
        _partDrafts.removeLast().dispose();
      }
    });
  }

  Future<int?> _createMaster(Map<String, dynamic> body) async {
    try {
      final response =
          await ApiHelper().postApiWithBody(ApiConstant.addShortMaster, body);
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['success'] == true &&
          decoded['data'] is Map<String, dynamic>) {
        return (decoded['data']['id'] as num?)?.toInt();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _createPart(Map<String, dynamic> body) async {
    try {
      final response =
          await ApiHelper().postApiWithBody(ApiConstant.createShortPart, body);
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == false) {
          return false;
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _submitBulk() async {
    if (_bulkEntries.isEmpty) {
      CustomToast.show(context, 'Select videos for bulk upload first.',
          isSuccess: false);
      return;
    }
    for (final entry in _bulkEntries) {
      if (entry.titleCtrl.text.trim().isEmpty ||
          entry.descCtrl.text.trim().isEmpty ||
          (entry.videoUrl?.trim().isEmpty ?? true)) {
        CustomToast.show(
          context,
          'Each bulk item needs title, description, and video upload.',
          isSuccess: false,
        );
        return;
      }
    }

    final localPrefs = LocalSharePreferences();
    final mediaHouse = await localPrefs.getMediaHouse();
    if (mediaHouse?.id == null) {
      CustomToast.show(context, 'Production house not found.',
          isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      for (final entry in _bulkEntries) {
        final masterId = await _createMaster({
          'title': entry.titleCtrl.text.trim(),
          'description': entry.descCtrl.text.trim(),
          'creatorName': '',
          'category': 'Bulk Upload',
          'totalParts': 1,
          'coinsPerPart': 0,
          'isTrending': false,
          'mediaHouseId': mediaHouse!.id,
          'posterUrl': entry.thumbnailUrl,
          'likeCount': 0,
          'viewCount': 0,
        });
        if (masterId == null) {
          throw Exception('Failed to create short master');
        }
        final created = await _createPart({
          'audioFileUrl': '',
          'coins': 0,
          'description': entry.descCtrl.text.trim(),
          'durationSec': 0,
          'id': 0,
          'isFreePreview': false,
          'likes': 0,
          'partNumber': 1,
          'shortId': masterId,
          'subtitleFileUrl': '',
          'thumbnail': entry.thumbnailUrl,
          'title': entry.titleCtrl.text.trim(),
          'videoUrl': entry.videoUrl,
          'views': 0,
        });
        if (!created) {
          throw Exception('Failed to create short part');
        }
      }
      if (!mounted) return;
      await context.read<ShortProvider>().fetchShorts();
      CustomToast.show(context, 'Bulk short upload completed.',
          isSuccess: true);
      Navigator.of(context).pop();
    } catch (error) {
      CustomToast.show(context, 'Unable to complete the bulk upload. Please try again.', isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _submitIndividual() async {
    _syncPartCount();
    if (!(_individualFormKey.currentState?.validate() ?? false)) return;

    final totalParts = int.tryParse(_partsCountCtrl.text.trim()) ?? 0;
    if (totalParts <= 0) {
      CustomToast.show(context, 'Enter a valid number of parts.',
          isSuccess: false);
      return;
    }
    if (_partDrafts.length != totalParts) {
      CustomToast.show(
        context,
        'Generated parts do not match the Number of Parts value.',
        isSuccess: false,
      );
      return;
    }
    final missing = _partDrafts.any((part) =>
        part.titleCtrl.text.trim().isEmpty ||
        part.descCtrl.text.trim().isEmpty ||
        (part.videoUrl?.trim().isEmpty ?? true));
    if (missing) {
      CustomToast.show(
        context,
        'Every part needs title, description, and uploaded video.',
        isSuccess: false,
      );
      return;
    }

    final localPrefs = LocalSharePreferences();
    final mediaHouse = await localPrefs.getMediaHouse();
    if (mediaHouse?.id == null) {
      CustomToast.show(context, 'Production house not found.',
          isSuccess: false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final masterId = await _createMaster({
        'title': _masterTitleCtrl.text.trim(),
        'description': _masterDescCtrl.text.trim(),
        'creatorName': '',
        'category': 'Individual Upload',
        'totalParts': totalParts,
        'coinsPerPart': 0,
        'isTrending': false,
        'mediaHouseId': mediaHouse!.id,
        'posterUrl': _masterThumbUrl,
        'likeCount': 0,
        'viewCount': 0,
      });
      if (masterId == null) {
        throw Exception('Failed to create short master');
      }

      for (final part in _partDrafts) {
        final created = await _createPart({
          'audioFileUrl': '',
          'coins': 0,
          'description': part.descCtrl.text.trim(),
          'durationSec': 0,
          'id': 0,
          'isFreePreview': part.isFreePreview,
          'likes': 0,
          'partNumber': part.partNumber,
          'shortId': masterId,
          'subtitleFileUrl': '',
          'thumbnail': part.thumbnailUrl,
          'title': part.titleCtrl.text.trim(),
          'videoUrl': part.videoUrl,
          'views': 0,
        });
        if (!created) {
          throw Exception('Failed to upload part ${part.partNumber}');
        }
      }

      if (!mounted) return;
      await context.read<ShortProvider>().fetchShorts();
      CustomToast.show(context, 'Short created successfully.', isSuccess: true);
      Navigator.of(context).pop();
    } catch (error) {
      CustomToast.show(context, 'Unable to upload the short. Please try again.',
          isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().getTheme;
    final isNarrow = MediaQuery.of(context).size.width < 900;
    return Container(
      width: isNarrow ? MediaQuery.of(context).size.width * 0.94 : 1040,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeSelector(theme),
                  const SizedBox(height: 20),
                  if (_mode == ShortUploadMode.bulk)
                    _buildBulkSection(theme)
                  else
                    _buildIndividualSection(theme),
                ],
              ),
            ),
          ),
          _buildFooter(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Short Upload',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload shorts in bulk or create one short master with multiple parts.',
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

  Widget _buildModeSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _modeCard(
            theme,
            title: 'Bulk Upload',
            subtitle: 'Upload multiple short videos at once',
            icon: Icons.video_library_outlined,
            selected: _mode == ShortUploadMode.bulk,
            onTap: () => setState(() => _mode = ShortUploadMode.bulk),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _modeCard(
            theme,
            title: 'Individual Upload',
            subtitle: 'Create one short with multiple parts',
            icon: Icons.view_stream_outlined,
            selected: _mode == ShortUploadMode.individual,
            onTap: () => setState(() => _mode = ShortUploadMode.individual),
          ),
        ),
      ],
    );
  }

  Widget _modeCard(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? theme.primaryColor
                : theme.dividerColor.withValues(alpha: 0.35),
          ),
          color: selected
              ? theme.primaryColor.withValues(alpha: 0.08)
              : theme.scaffoldBackgroundColor.withValues(alpha: 0.45),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.canvasColor.withValues(alpha: 0.68),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkSection(ThemeData theme) {
    return _sectionCard(
      theme,
      title: 'Bulk Upload',
      subtitle:
          'Select multiple videos. Each uploaded video will become a separate short item.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _isSubmitting || _isPickingBulkVideos
                    ? null
                    : _pickBulkVideos,
                icon: _isPickingBulkVideos
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.video_collection_outlined),
                label: Text(
                  _isPickingBulkVideos ? 'Selecting...' : 'Select Videos',
                ),
              ),
              Text(
                '${_bulkEntries.length} item(s) ready',
                style: TextStyle(
                  color: theme.canvasColor.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          if (_bulkEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            ..._bulkEntries.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildBulkEntryCard(theme, entry.key, entry.value),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkEntryCard(
      ThemeData theme, int index, _BulkShortEntry entry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Short ${index + 1}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _bulkEntries.removeAt(index).dispose();
                        });
                      },
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _textField(theme, entry.titleCtrl, 'Title'),
          const SizedBox(height: 12),
          _textField(theme, entry.descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          _uploadStatusRow(
            theme,
            label: 'Video File',
            fileName: entry.videoFileName ?? 'No video selected',
            uploading: entry.isUploadingVideo,
            uploaded: entry.videoUrl?.isNotEmpty == true,
            onTap: null,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _isSubmitting ? null : () => _pickBulkThumbnail(entry),
                icon: entry.isUploadingThumb
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined),
                label: Text(
                  entry.thumbnailUrl?.isNotEmpty == true
                      ? 'Change Thumbnail'
                      : 'Upload Thumbnail',
                ),
              ),
              if (entry.thumbnailPreview != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    entry.thumbnailPreview!,
                    height: 42,
                    width: 64,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualSection(ThemeData theme) {
    return Form(
      key: _individualFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(
            theme,
            title: 'Short Master',
            subtitle:
                'Define the base title, description, and number of parts.',
            child: Column(
              children: [
                _textField(
                  theme,
                  _masterTitleCtrl,
                  'Title',
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                _textField(
                  theme,
                  _masterDescCtrl,
                  'Description',
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _textField(
                        theme,
                        _partsCountCtrl,
                        'Number of Parts',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final count = int.tryParse((value ?? '').trim());
                          if (count == null || count <= 0) {
                            return 'Enter valid parts';
                          }
                          return null;
                        },
                        onChanged: (_) => _syncPartCount(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploadingMasterThumb || _isSubmitting
                            ? null
                            : _pickMasterThumbnail,
                        icon: _isUploadingMasterThumb
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Master Thumbnail'),
                      ),
                    ),
                  ],
                ),
                if (_masterThumbPreview != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _masterThumbPreview!,
                        height: 72,
                        width: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _sectionCard(
            theme,
            title: 'Short Parts Upload Section',
            subtitle:
                'Each part inherits the Short Master title and description by default, but remains editable.',
            child: Column(
              children: [
                ..._partDrafts.map((part) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPartCard(theme, part),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartCard(ThemeData theme, _PartDraft part) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Part ${part.partNumber}',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (part.titleIsInherited || part.descriptionIsInherited)
                Text(
                  'Inherited defaults active',
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _textField(theme, part.titleCtrl, 'Title'),
          const SizedBox(height: 12),
          _textField(theme, part.descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          _uploadStatusRow(
            theme,
            label: 'Video Upload',
            fileName: part.videoFileName ?? 'No video uploaded',
            uploading: part.isUploadingVideo,
            uploaded: part.videoUrl?.isNotEmpty == true,
            onTap: _isSubmitting ? null : () => _pickPartVideo(part),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSubmitting || part.isUploadingThumb
                      ? null
                      : () => _pickPartThumbnail(part),
                  icon: part.isUploadingThumb
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    part.thumbnailUrl?.isNotEmpty == true
                        ? 'Change Thumbnail'
                        : 'Optional Thumbnail',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Free Preview',
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontSize: 13,
                    ),
                  ),
                  value: part.isFreePreview,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => part.isFreePreview = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _uploadStatusRow(
    ThemeData theme, {
    required String label,
    required String fileName,
    required bool uploading,
    required bool uploaded,
    required VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.check_circle : Icons.movie_creation_outlined,
            color: uploaded ? const Color(0xFF0F9D58) : theme.primaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.canvasColor.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  uploading ? 'Uploading...' : fileName,
                  style: TextStyle(
                    color: theme.canvasColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            ElevatedButton(
              onPressed: onTap,
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
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.28),
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

  Widget _textField(
    ThemeData theme,
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
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
              BorderSide(color: theme.dividerColor.withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
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
            onPressed: _isSubmitting
                ? null
                : _mode == ShortUploadMode.bulk
                    ? _submitBulk
                    : _submitIndividual,
            icon: _isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_mode == ShortUploadMode.bulk
                    ? Icons.cloud_upload_outlined
                    : Icons.save_outlined),
            label: Text(
              _mode == ShortUploadMode.bulk
                  ? 'Submit Bulk Upload'
                  : 'Submit Individual Upload',
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkShortEntry {
  _BulkShortEntry({
    required String title,
    required String description,
  })  : titleCtrl = TextEditingController(text: title),
        descCtrl = TextEditingController(text: description);

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  String? videoUrl;
  String? videoFileName;
  String? thumbnailUrl;
  Uint8List? thumbnailPreview;
  bool isUploadingVideo = false;
  bool isUploadingThumb = false;

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

class _PartDraft {
  _PartDraft(this.partNumber)
      : titleCtrl = TextEditingController(),
        descCtrl = TextEditingController() {
    titleCtrl.addListener(() {
      if (!_updatingTitleInternally) {
        titleIsInherited = false;
      }
    });
    descCtrl.addListener(() {
      if (!_updatingDescInternally) {
        descriptionIsInherited = false;
      }
    });
  }

  final int partNumber;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  String? videoUrl;
  String? videoFileName;
  String? thumbnailUrl;
  Uint8List? thumbnailPreview;
  bool isUploadingVideo = false;
  bool isUploadingThumb = false;
  bool isFreePreview = false;
  bool titleIsInherited = true;
  bool descriptionIsInherited = true;
  bool _updatingTitleInternally = false;
  bool _updatingDescInternally = false;

  void setTitle(String value) {
    _updatingTitleInternally = true;
    titleCtrl.text = value;
    _updatingTitleInternally = false;
  }

  void setDescription(String value) {
    _updatingDescInternally = true;
    descCtrl.text = value;
    _updatingDescInternally = false;
  }

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
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
