import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/utils/image_validation_service.dart';
import 'package:media_house/app/provider/series_provider.dart';
import 'package:media_house/data/models/response/content_image_upload_response.dart';
import 'package:media_house/data/models/response/series_detail_response.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../provider/themeProvider.dart';
import '../../../widget/multipart_upload_progress_widget.dart';

class EditEpisodeDialog extends StatefulWidget {
  final Episode episode;
  final num seasonPrice;

  const EditEpisodeDialog({
    super.key,
    required this.episode,
    required this.seasonPrice,
  });

  @override
  State<EditEpisodeDialog> createState() => _EditEpisodeDialogState();
}

class _EditEpisodeDialogState extends State<EditEpisodeDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _episodeNoCtrl;
  late final TextEditingController _runtimeCtrl;
  late final TextEditingController _posterUrlCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _manualPriceCtrl;
  bool _isFree = false;
  bool _followSeasonPrice = true;
  double _posterUploadProgress = 0;
  bool _isPosterUploading = false;

  @override
  void initState() {
    super.initState();
    final ep = widget.episode;
    _titleCtrl = TextEditingController(text: ep.title ?? '');
    _descCtrl = TextEditingController(text: ep.description ?? '');
    _episodeNoCtrl = TextEditingController(text: '${ep.episodeNumber ?? 1}');
    _runtimeCtrl = TextEditingController(text: '${ep.runtime ?? 0}');
    _posterUrlCtrl = TextEditingController(text: ep.posterUrl ?? '');
    _videoUrlCtrl = TextEditingController(text: ep.videoUrl ?? '');
    final episodeAmount = ep.amount ?? widget.seasonPrice;
    _manualPriceCtrl = TextEditingController(text: '$episodeAmount');
    _followSeasonPrice = episodeAmount == widget.seasonPrice;
    _isFree = ep.free ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _episodeNoCtrl.dispose();
    _runtimeCtrl.dispose();
    _posterUrlCtrl.dispose();
    _videoUrlCtrl.dispose();
    _manualPriceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    final seriesProvider = context.watch<SeriesProvider>();
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
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Edit Episode',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: theme.canvasColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _section(theme, 'Basic Details', [
                    _field(
                      _titleCtrl,
                      'Title',
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Title is required';
                        if (t.length < 2) return 'Enter valid title';
                        return null;
                      },
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    _field(
                      _descCtrl,
                      'Description',
                      maxLines: 3,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Description is required';
                        if (t.length < 5) return 'Description is too short';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _section(theme, 'Pricing & Runtime', [
                    _priceSelector(theme),
                    /*    _field(
                      _episodeNoCtrl,
                      'Episode Number',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter valid episode number';
                        if (n <= 0) return 'Episode number must be > 0';
                        return null;
                      },
                    ),
                    _field(
                      _runtimeCtrl,
                      'Runtime (min)',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter valid runtime';
                        if (n < 0) return 'Runtime cannot be negative';
                        return null;
                      },
                    ),
                    */
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Free Preview',
                        style: TextStyle(color: theme.canvasColor),
                      ),
                      value: _isFree,
                      onChanged: (value) => setState(() => _isFree = value),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  _section(theme, 'Media URLs', [
                    _posterUploadRow(theme),
                    _videoUploadRow(theme, seriesProvider),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Save'),
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
          ...children.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false).getTheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: theme.canvasColor),
        ),
      ),
    );
  }

  Widget _priceSelector(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              _followSeasonPrice
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: theme.canvasColor,
            ),
            title: Text(
              'Follow season price: Rs ${widget.seasonPrice}',
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => setState(() => _followSeasonPrice = true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              !_followSeasonPrice
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: theme.canvasColor,
            ),
            title: Text(
              'Enter manual episode price',
              style: TextStyle(
                color: theme.canvasColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => setState(() => _followSeasonPrice = false),
          ),
          if (!_followSeasonPrice)
            _field(
              _manualPriceCtrl,
              'Episode Price',
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null) return 'Enter valid episode price';
                if (n < 0) return 'Episode price cannot be negative';
                return null;
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickPoster() async {
    if (_isPosterUploading) return;

    try {
      setState(() {
        _isPosterUploading = true;
        _posterUploadProgress = 0.1;
      });

      Uint8List bytes;
      String fileName = 'episode_poster.jpg';

      if (kIsWeb) {
        final input = html.FileUploadInputElement()..accept = 'image/*';
        input.click();
        await input.onChange.first;
        if (input.files == null || input.files!.isEmpty) return;
        final file = input.files!.first;
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        bytes = Uint8List.fromList((reader.result as List).cast<int>());
        fileName = file.name;
        final validation = await ImageValidationService.validateBytes(
          bytes: bytes,
          fileName: fileName,
          sizeInBytes: file.size,
          type: ImageValidationType.thumbnail,
        );
        if (!validation.isValid) {
          throw Exception(validation.message ?? 'Invalid image');
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        bytes = await io.File(picked.path).readAsBytes();
        fileName = picked.name;
        final validation = await ImageValidationService.validateBytes(
          bytes: bytes,
          fileName: fileName,
          sizeInBytes: bytes.lengthInBytes,
          type: ImageValidationType.thumbnail,
        );
        if (!validation.isValid) {
          throw Exception(validation.message ?? 'Invalid image');
        }
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadContentImg),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      setState(() => _posterUploadProgress = 0.4);
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final parsed = ContentImageUploadResponse.fromJson(jsonDecode(body));
      final url = parsed.data?.fileUrl?.trim();
      if (url == null || url.isEmpty) {
        throw Exception('Poster upload response did not include URL.');
      }

      setState(() {
        _posterUrlCtrl.text = url;
        _posterUploadProgress = 1;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to upload the poster. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosterUploading = false;
          if (_posterUploadProgress < 1) _posterUploadProgress = 0;
        });
      }
    }
  }

  Widget _posterUploadRow(ThemeData theme) {
    final hasPoster = _posterUrlCtrl.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasPoster ? 'Poster uploaded' : 'No poster selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.canvasColor),
              ),
            ),
            TextButton.icon(
              onPressed: _isPosterUploading ? null : _pickPoster,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(hasPoster ? 'Replace Poster' : 'Upload Poster'),
            ),
          ],
        ),
        if (_isPosterUploading)
          LinearProgressIndicator(value: _posterUploadProgress.clamp(0, 1)),
      ],
    );
  }

  Widget _videoUploadRow(ThemeData theme, SeriesProvider provider) {
    final hasVideo = _videoUrlCtrl.text.trim().isNotEmpty;
    final isUploading = provider.isMovieUploading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                hasVideo ? 'Episode file uploaded' : 'No episode file selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.canvasColor),
              ),
            ),
            TextButton.icon(
              onPressed: isUploading
                  ? null
                  : () async {
                      await provider.uploadVideo(false);
                      if (!mounted) return;
                      final uploadedUrl =
                          provider.movieUrlController.text.trim();
                      if (uploadedUrl.isEmpty) return;
                      setState(() {
                        _videoUrlCtrl.text = uploadedUrl;
                        if (provider.episodeVideoRuntime > 0) {
                          _runtimeCtrl.text =
                              provider.episodeVideoRuntime.toString();
                        }
                      });
                      provider.movieUrlController.clear();
                      provider.episodeVideoRuntime = 0;
                    },
              icon: const Icon(Icons.video_file_outlined, size: 18),
              label: Text(hasVideo ? 'Replace File' : 'Upload File'),
            ),
          ],
        ),
        if (isUploading)
          LinearProgressIndicator(
            value: provider.movieUploadProgress.clamp(0, 1),
          ),
        if (provider.getEpisodeProgressInfo('episode_${widget.episode.id}') != null) ...[
          const SizedBox(height: 10),
          MultipartUploadProgressWidget(
            info: provider.getEpisodeProgressInfo('episode_${widget.episode.id}')!,
            onPause: () => provider.pauseEpisodeMultipartUpload('episode_${widget.episode.id}'),
            onResume: () => provider.resumeEpisodeMultipartUpload('episode_${widget.episode.id}'),
            onRetry: () => provider.retryEpisodeMultipartUpload('episode_${widget.episode.id}'),
            onAbort: () => provider.abortEpisodeMultipartUpload('episode_${widget.episode.id}', context: context),
          ),
        ],
      ],
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleCtrl.text.trim();
    final episodeAmount = _followSeasonPrice
        ? widget.seasonPrice
        : (num.tryParse(_manualPriceCtrl.text.trim()) ?? 0);
    final body = <String, dynamic>{
      "amount": episodeAmount,
      "title": title,
      "description": _descCtrl.text.trim(),
      "episodeNumber": int.parse(_episodeNoCtrl.text.trim()),
      "partName": title,
      "free": _isFree,
      "posterUrl": _posterUrlCtrl.text.trim(),
      "videoUrl": _videoUrlCtrl.text.trim(),
      "releaseDate": DateTime.now().toUtc().toIso8601String(),
      "runtime": int.parse(_runtimeCtrl.text.trim()),
    };

    Navigator.pop(context, body);
  }
}
