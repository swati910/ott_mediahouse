import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../../data/models/response/short_detail_response.dart';
import '../../../../core/constant/api_constant.dart';
import '../../../../core/utils/image_validation_service.dart';
import '../../../../provider/shorts_provider.dart';
import '../../../../widget/show_toast.dart';
import '../../../widget/multipart_upload_progress_widget.dart';

class EditShortPartDialog extends StatefulWidget {
  final int shortId;
  final ShortPartModel part;

  const EditShortPartDialog({
    super.key,
    required this.shortId,
    required this.part,
  });

  @override
  State<EditShortPartDialog> createState() => _EditShortPartDialogState();
}

class _EditShortPartDialogState extends State<EditShortPartDialog> {
  late TextEditingController titleCtrl;
  late TextEditingController videoUrlCtrl;
  late TextEditingController coinUrlCtrl;

  bool isFreePreview = false;
  Uint8List? previewBytes;
  String? uploadedImageUrl;
  late String _initialTitle;
  late String _initialVideoUrl;
  late String _initialThumbnail;
  late bool _initialFreePreview;
  late String _intialCoin;

  @override
  void initState() {
    super.initState();

    titleCtrl = TextEditingController(text: widget.part.title);
    coinUrlCtrl = TextEditingController(text: widget.part.coins.toString());
    videoUrlCtrl = TextEditingController(text: widget.part.videoUrl ?? "");

    isFreePreview = widget.part.isFreePreview ?? false;
    uploadedImageUrl = widget.part.thumbnail;

    _initialTitle = titleCtrl.text;
    _initialVideoUrl = videoUrlCtrl.text;
    _initialThumbnail = uploadedImageUrl!;
    _initialFreePreview = isFreePreview;
    //  _intialCoin = coinUrlCtrl.text;

    /// ✅ LISTEN FOR VIDEO UPLOAD RESULT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ShortProvider>();

      provider.movieUrlController.addListener(() {
        final url = provider.movieUrlController.text;
        if (url.isNotEmpty && mounted) {
          setState(() {
            videoUrlCtrl.text = url;
          });
        }
      });
    });

    titleCtrl.addListener(() => setState(() {}));
  }

  bool get _hasChanges {
    return titleCtrl.text.trim() != _initialTitle ||
        //    coinUrlCtrl.text.trim() != _intialCoin ||
        videoUrlCtrl.text.trim() != _initialVideoUrl ||
        uploadedImageUrl != _initialThumbnail ||
        isFreePreview != _initialFreePreview;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShortProvider>();
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 720,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _darkField("Title", titleCtrl),
                    //  _darkField("Price", coinUrlCtrl),
                    _videoCard(provider),
                    _thumbnailCard(),
                    _freePreviewSwitch(),
                  ],
                ),
              ),
            ),
            _footer(provider),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // HEADER
  // ===============================================================

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.orange.withOpacity(0.4)),
        ),
      ),
      child: Row(
        children: [
          const Text(
            "Edit Short Part",
            style: TextStyle(
              color: Colors.orange,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // FIELDS
  // ===============================================================

  Widget _darkField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: const Color(0xFF141414),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // VIDEO CARD (CREATE-LIKE)
  // ===============================================================

  Widget _videoCard(ShortProvider provider) {
    final hasVideo = videoUrlCtrl.text.isNotEmpty;

    return _uploadCard(
      title: "Movie File",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ⏳ UPLOADING
          if (provider.isMovieUploading) ...[
            LinearProgressIndicator(
              value: provider.movieUploadProgress,
              color: Colors.orange,
            ),
          ]

          /// ✅ UPLOADED
          else if (hasVideo) ...[
            _successRow(videoUrlCtrl.text),
            const SizedBox(height: 12),
            _actionRow(
              onReplace: provider.isMovieUploading
                  ? () {}
                  : () => provider.uploadVideo(false),
              onRemove: () {
                setState(() {
                  videoUrlCtrl.clear();
                });
              },
            ),
          ]

          /// ⬆️ UPLOAD BUTTON
          else ...[
            _uploadButton(
              label: "Upload Video",
              onTap: () => provider.uploadVideo(false),
            ),
          ],
          if (provider.getPartProgressInfo('part_${widget.part.partId}') !=
              null) ...[
            const SizedBox(height: 10),
            MultipartUploadProgressWidget(
              info: provider.getPartProgressInfo('part_${widget.part.partId}')!,
              onPause: () => provider
                  .pausePartMultipartUpload('part_${widget.part.partId}'),
              onResume: () => provider
                  .resumePartMultipartUpload('part_${widget.part.partId}'),
              onRetry: () => provider
                  .retryPartMultipartUpload('part_${widget.part.partId}'),
              onAbort: () => provider
                  .abortPartMultipartUpload('part_${widget.part.partId}'),
            ),
          ],
        ],
      ),
    );
  }

  // ===============================================================
  // THUMBNAIL CARD (CREATE-LIKE)
  // ===============================================================

  Widget _thumbnailCard() {
    final hasThumb = uploadedImageUrl != null;

    return _uploadCard(
      title: "Thumbnail",
      child: hasThumb
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    uploadedImageUrl!,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                _actionRow(
                  onReplace: () async {
                    await pickImage(setState);
                  },
                  onRemove: () {
                    setState(() {
                      uploadedImageUrl = null;
                    });
                  },
                ),
              ],
            )
          : _uploadButton(
              label: "Upload Thumbnail",
              onTap: () async {
                await pickImage(setState);
              },
            ),
    );
  }

  Widget _actionRow({
    required VoidCallback onReplace,
    required VoidCallback onRemove,
  }) {
    return Row(
      children: [
        TextButton(
          onPressed: onReplace,
          child: const Text(
            "Replace",
            style: TextStyle(color: Colors.orange),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete, color: Colors.red),
        ),
      ],
    );
  }

  Widget _uploadButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.orange),
        ),
      ),
    );
  }

  Widget _uploadCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.25),
            Colors.orange.withOpacity(0.25),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _successRow(String value) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // FREE PREVIEW
  // ===============================================================

  Widget _freePreviewSwitch() {
    return SwitchListTile(
      value: isFreePreview,
      activeColor: Colors.orange,
      title: const Text(
        "Free Preview",
        style: TextStyle(color: Colors.white),
      ),
      onChanged: (v) => setState(() => isFreePreview = v),
    );
  }

  // ===============================================================
  // FOOTER
  // ===============================================================

  Widget _footer(ShortProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.orange.withOpacity(0.4)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          onPressed: provider.isSubmitting || !_hasChanges ? null : _submit,
          child: provider.isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Update Part"),
        ),
      ),
    );
  }

  // ===============================================================
  // SUBMIT
  // ===============================================================

  Future<void> _submit() async {
    final provider = context.read<ShortProvider>();

    final body = {
      //  "coins": coinUrlCtrl.text.trim(),
      "id": widget.part.partId,
      "isFreePreview": isFreePreview,
      "thumbnail": uploadedImageUrl,
      "title": titleCtrl.text.trim(),
      "videoUrl": videoUrlCtrl.text.trim(),
    };

    final success = await provider.updateShortPart(body, widget.part.partId!);

    if (!mounted) return;

    if (success) {
      CustomToast.show(context, "Part updated successfully", isSuccess: true);
      Navigator.pop(context, true);
      return;
    }

    CustomToast.show(context, "Failed to update part. Please try again.",
        isSuccess: false);
  }

  io.File? imageFile;
  html.File? webFile;
  double uploadProgress = 0;

  Future<void> uploadImage(StateSetter setState) async {
    debugPrint(" uploade image url : ${ApiConstant.uploadContentImg}");
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
        previewBytes = bytes;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: webFile!.name,
          ),
        );
      } else if (!kIsWeb && imageFile != null) {
        bytes = await imageFile!.readAsBytes();
        previewBytes = bytes;

        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: imageFile!.path.split('/').last,
          ),
        );
      } else {
        return;
      }

      setState(() => uploadProgress = 0.3);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      final decoded = jsonDecode(responseBody);
      final res = ContentImageUploadResponse.fromJson(decoded);

      uploadedImageUrl = res.data?.fileUrl;

      if (uploadedImageUrl == null || uploadedImageUrl!.isEmpty) {
        throw Exception("Thumbnail URL not received");
      }

      debugPrint("✅ Thumbnail uploaded: $uploadedImageUrl");

      setState(() => uploadProgress = 1);
    } catch (e) {
      uploadProgress = 0;
      debugPrint("❌ Upload error: $e");
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
          CustomToast.show(context, validation.message ?? "Invalid image",
              isSuccess: false);
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
          CustomToast.show(context, validation.message ?? "Invalid image",
              isSuccess: false);
          return;
        }
        imageFile = io.File(file.path);
        previewBytes = bytes;
        await uploadImage(setState);
        setState(() {});
      }
    }
  }
}
