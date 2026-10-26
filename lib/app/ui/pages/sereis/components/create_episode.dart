import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:media_house/app/provider/series_provider.dart';
import 'package:media_house/app/provider/themeProvider.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../core/constant/api_constant.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/image_validation_service.dart';
import '../../DisplayTrailer.dart';

class AddEpisodeDialog extends StatefulWidget {
  final int seriesId;
  final int seasonId;
  final num seasonPrice;
  final String seriesLanguage;
  final FutureOr<void> Function() onSuccess;

  const AddEpisodeDialog({
    super.key,
    required this.seriesId,
    required this.seasonId,
    required this.seasonPrice,
    required this.seriesLanguage,
    required this.onSuccess,
  });

  @override
  State<AddEpisodeDialog> createState() => _AddEpisodeDialogState();
}

class _AddEpisodeDialogState extends State<AddEpisodeDialog> {
  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final episodeNoCtrl = TextEditingController();
  final runtimeCtrl = TextEditingController(text: '0');
  final releaseDateCtrl = TextEditingController();
  final manualPriceCtrl = TextEditingController();

  bool isLoading = false;
  bool isFreePreview = false;
  bool followSeasonPrice = true;

  String? uploadedImageUrl;

  /// THUMBNAIL
  io.File? imageFile;
  html.File? webFile;
  Uint8List? previewBytes;
  double uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    releaseDateCtrl.text = _formatDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SeriesProvider>().clearEpisodeUploadDraft();
    });
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    episodeNoCtrl.dispose();
    runtimeCtrl.dispose();
    releaseDateCtrl.dispose();
    manualPriceCtrl.dispose();
    super.dispose();
  }

  // ===============================================================
  // GLOBAL SNACK
  // ===============================================================

  void showGlobalSnack(String message) {
    globalMessengerKey.currentState
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  String _responseMessage(String body, String fallback) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        for (final key in const ['message', 'error', 'details']) {
          final value = decoded[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _showResultDialog({
    required bool success,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(success ? "Episode Added" : "Episode Failed"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ===============================================================
  // IMAGE UPLOAD
  // ===============================================================

  Future<void> uploadImage(StateSetter setState) async {
    try {
      final uri = Uri.parse(ApiConstant.uploadContentImg);
      uploadProgress = 0;

      http.MultipartRequest request = http.MultipartRequest('POST', uri);

      Uint8List bytes;

      if (kIsWeb && webFile != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(webFile!);
        await reader.onLoad.first;
        bytes = Uint8List.fromList(reader.result as List<int>);
      } else if (!kIsWeb && imageFile != null) {
        bytes = await imageFile!.readAsBytes();
      } else {
        return;
      }

      previewBytes = bytes;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'thumb.jpg',
        ),
      );

      setState(() => uploadProgress = 0.3);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      final decoded = jsonDecode(responseBody);
      final res = ContentImageUploadResponse.fromJson(decoded);

      uploadedImageUrl = res.data?.fileUrl;

      if (uploadedImageUrl == null || uploadedImageUrl!.isEmpty) {
        throw Exception("Thumbnail URL missing");
      }

      setState(() => uploadProgress = 1);
    } catch (e) {
      uploadProgress = 0;
      showGlobalSnack("Thumbnail upload failed");
      debugPrint("Thumbnail upload error => $e");
    }
  }

  Future<void> pickImage(StateSetter setState) async {
    if (kIsWeb) {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      input.click();
      input.onChange.listen((_) async {
        if (input.files == null || input.files!.isEmpty) return;
        final file = input.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = Uint8List.fromList((reader.result as List).cast<int>());
        final validation = await ImageValidationService.validateBytes(
          bytes: bytes,
          fileName: file.name,
          sizeInBytes: file.size,
          type: ImageValidationType.thumbnail,
        );
        if (!validation.isValid) {
          showGlobalSnack(validation.message ?? "Invalid image");
          return;
        }
        webFile = file;
        previewBytes = bytes;
        await uploadImage(setState);
        setState(() {});
      });
    } else {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        final bytes = await file.readAsBytes();
        final validation = await ImageValidationService.validateBytes(
          bytes: bytes,
          fileName: file.name,
          sizeInBytes: bytes.lengthInBytes,
          type: ImageValidationType.thumbnail,
        );
        if (!validation.isValid) {
          showGlobalSnack(validation.message ?? "Invalid image");
          return;
        }
        imageFile = io.File(file.path);
        previewBytes = bytes;
        await uploadImage(setState);
        setState(() {});
      }
    }
  }

  // ===============================================================
  // UI
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SeriesProvider>();
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Add Episode - ${widget.seriesLanguage}",
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: theme.canvasColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _section(theme, "Basic Details", [
                    _field(titleCtrl, "Title"),
                    _field(descCtrl, "Description", maxLines: 3),
                    _field(
                      episodeNoCtrl,
                      "Episode Number",
                      keyboard: TextInputType.number,
                    ),
                    _releaseDateField(theme),
                  ]),
                  const SizedBox(height: 10),
                  _section(theme, "Pricing", [
                    _priceSection(theme),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Free Preview",
                        style: TextStyle(color: theme.canvasColor),
                      ),
                      value: isFreePreview,
                      onChanged: (value) =>
                          setState(() => isFreePreview = value),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _section(theme, "Media Files", [
                    _videoUploadCard(provider, theme),
                    _field(
                      runtimeCtrl,
                      "Runtime",
                      keyboard: TextInputType.number,
                    ),
                    _thumbnailUploadCard(theme),
                    _episodeFileRow(
                      theme: theme,
                      title: "Audio File",
                      uploaded: provider.episodeAudioUrlController.text
                          .trim()
                          .isNotEmpty,
                      uploading: provider.isEpisodeAudioUploading,
                      progress: provider.episodeAudioUploadProgress,
                      fileName: provider.episodeAudioFileName,
                      icon: Icons.audiotrack_outlined,
                      onTap: () => _uploadEpisodeAudio(provider),
                      onRemove: provider.clearEpisodeAudioDraft,
                    ),
                    _episodeFileRow(
                      theme: theme,
                      title: "Subtitle File",
                      uploaded: provider.episodeSubtitleUrlController.text
                          .trim()
                          .isNotEmpty,
                      uploading: provider.isEpisodeSubtitleUploading,
                      progress: provider.episodeSubtitleUploadProgress,
                      fileName: provider.episodeSubtitleFileName,
                      icon: Icons.subtitles_outlined,
                      onTap: () => _uploadEpisodeSubtitle(provider),
                      onRemove: provider.clearEpisodeSubtitleDraft,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading ? null : () => _submit(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Add"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _releaseDateField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: releaseDateCtrl,
        readOnly: true,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: "Release Date",
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onTap: () async {
          final initialDate =
              DateTime.tryParse(releaseDateCtrl.text.trim()) ?? DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                  data: theme, child: child ?? const SizedBox.shrink());
            },
          );
          if (picked != null) {
            setState(() => releaseDateCtrl.text = _formatDate(picked));
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  String _releaseDateIso() {
    final date = DateTime.tryParse(releaseDateCtrl.text.trim());
    return (date ?? DateTime.now()).toUtc().toIso8601String();
  }

  Future<void> _uploadEpisodeAudio(SeriesProvider provider) async {
    try {
      await provider.pickEpisodeAudioFile();
    } catch (error) {
      showGlobalSnack("Audio upload failed: $error");
    }
  }

  Future<void> _uploadEpisodeSubtitle(SeriesProvider provider) async {
    try {
      await provider.pickEpisodeSubtitleFile();
    } catch (error) {
      showGlobalSnack("Subtitle upload failed: $error");
    }
  }

  Widget _episodeFileRow({
    required ThemeData theme,
    required String title,
    required bool uploaded,
    required bool uploading,
    required double progress,
    required String? fileName,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  uploaded ? (fileName ?? "$title uploaded") : "No $title",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.canvasColor),
                ),
              ),
              if (uploaded)
                IconButton(
                  tooltip: "Remove",
                  onPressed: uploading ? null : onRemove,
                  icon: Icon(Icons.close, color: theme.canvasColor, size: 18),
                ),
              TextButton.icon(
                onPressed: uploading ? null : onTap,
                icon: Icon(
                  uploaded ? Icons.swap_horiz : Icons.upload_file,
                  size: 18,
                ),
                label: Text(uploaded ? "Replace" : "Upload"),
              ),
            ],
          ),
          if (uploading)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(value: progress.clamp(0, 1)),
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // SUBMIT
  // ===============================================================

  Future<void> _submit(SeriesProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    if (uploadedImageUrl == null || uploadedImageUrl!.isEmpty) {
      showGlobalSnack("Please upload thumbnail");
      return;
    }

    if (provider.movieUrlController.text.isEmpty) {
      showGlobalSnack("Please upload episode video");
      return;
    }
    final episodeNumber = int.tryParse(episodeNoCtrl.text.trim());
    if (episodeNumber == null) {
      showGlobalSnack("Please enter a valid episode number");
      return;
    }
    final episodeAmount = followSeasonPrice
        ? widget.seasonPrice
        : num.tryParse(manualPriceCtrl.text.trim());
    if (episodeAmount == null || episodeAmount < 0) {
      showGlobalSnack("Please enter a valid episode price");
      return;
    }
    final runtime = int.tryParse(runtimeCtrl.text.trim());
    if (runtime == null || runtime < 0) {
      showGlobalSnack("Please enter a valid runtime");
      return;
    }

    setState(() => isLoading = true);

    final body = {
      "amount": episodeAmount,
      "audioFileUrl": provider.episodeAudioUrlController.text.trim(),
      "description": descCtrl.text.trim(),
      "episodeNumber": episodeNumber,
      "free": isFreePreview,
      "partName": titleCtrl.text.trim(),
      "posterUrl": uploadedImageUrl,
      "releaseDate": _releaseDateIso(),
      "runtime": runtime,
      "subtitleFileUrl": provider.episodeSubtitleUrlController.text.trim(),
      "title": titleCtrl.text.trim(),
      "videoUrl": provider.movieUrlController.text.trim(),
    };

    final response = await provider.createEpisodeApiResponse(
      body,
      widget.seasonId,
    );

    if (!mounted) return;

    setState(() => isLoading = false);
    final success = response != null &&
        (response.statusCode == 200 || response.statusCode == 201);

    if (success) {
      await _showResultDialog(
        success: true,
        message: _responseMessage(
          response.body,
          "Episode added successfully.",
        ),
      );
      if (!mounted) return;
      await widget.onSuccess();
      if (!mounted) return;
      provider.clearEpisodeUploadDraft();
      Navigator.pop(context, true);
    } else {
      await _showResultDialog(
        success: false,
        message: _responseMessage(
          response?.body ?? '',
          "Failed to save episode.",
        ),
      );
    }
  }

  // ===============================================================
  // VIDEO CARD
  // ===============================================================

  Widget _videoUploadCard(SeriesProvider provider, ThemeData theme) {
    final isUploaded = provider.movieUrlController.text.isNotEmpty &&
        !provider.isMovieUploading;

    return _uploadCard(
      title: "Episode File",
      theme: theme,
      uploading: provider.isMovieUploading,
      progress: provider.movieUploadProgress,
      uploadedFileName: isUploaded ? "Video Uploaded" : null,
      onPreview: () => _previewVideo(provider.movieUrlController.text),
      onRemove: () => provider.movieUrlController.clear(),
      onReplace: () => _uploadEpisodeVideo(provider),
      onTap: () => _uploadEpisodeVideo(provider),
    );
  }

  Future<void> _uploadEpisodeVideo(SeriesProvider provider) async {
    await provider.uploadVideo(false);
    if (!mounted) return;
    final runtime = provider.episodeVideoRuntime;
    if (runtime > 0) {
      setState(() => runtimeCtrl.text = runtime.toString());
    }
  }

  Widget _priceSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              followSeasonPrice
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: theme.canvasColor,
            ),
            title: Text(
              "Follow season price: Rs ${widget.seasonPrice}",
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => setState(() => followSeasonPrice = true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              !followSeasonPrice
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: theme.canvasColor,
            ),
            title: Text(
              "Enter manual episode price",
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => setState(() => followSeasonPrice = false),
          ),
          if (!followSeasonPrice)
            _field(
              manualPriceCtrl,
              "Episode Price",
              keyboard: TextInputType.number,
            ),
        ],
      ),
    );
  }

  Widget _thumbnailUploadCard(ThemeData theme) {
    return StatefulBuilder(
      builder: (_, setState) {
        return _uploadCard(
          title: "Episode Poster",
          theme: theme,
          uploading: uploadProgress > 0 && uploadProgress < 1,
          progress: uploadProgress,
          preview: previewBytes,
          onTap: () => pickImage(setState),
        );
      },
    );
  }

  void _previewVideo(String url) {
    if (kIsWeb) {
      html.window.open(url, "_blank");
    } else {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: TrailerPage(trailerUrl: url),
          ),
        ),
      );
    }
  }

  // ===============================================================
  // UPLOAD CARD
  // ===============================================================

  Widget _uploadCard({
    required String title,
    required ThemeData theme,
    required bool uploading,
    required double progress,
    required VoidCallback onTap,
    Uint8List? preview,
    String? uploadedFileName,
    VoidCallback? onPreview,
    VoidCallback? onRemove,
    VoidCallback? onReplace,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: theme.canvasColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (preview != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(preview, height: 120),
            ),
          if (uploadedFileName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(uploadedFileName,
                      style: const TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ] else if (uploading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ] else ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTap,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor),
                ),
                child: Text(
                  "Upload File",
                  style: TextStyle(color: theme.primaryColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
