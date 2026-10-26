import 'dart:convert';
import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../core/constant/api_constant.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/network/api_helper.dart';
import '../../../../core/utils/image_validation_service.dart';
import '../../../../provider/series_provider.dart';
import '../../../../provider/themeProvider.dart';

class AddSeasonDialog extends StatefulWidget {
  final int seriesId;
  final String seriesLanguage;
  final VoidCallback onSuccess;

  const AddSeasonDialog({
    super.key,
    required this.seriesId,
    required this.seriesLanguage,
    required this.onSuccess,
  });

  @override
  State<AddSeasonDialog> createState() => _AddSeasonDialogState();
}

class _AddSeasonDialogState extends State<AddSeasonDialog> {
  final _formKey = GlobalKey<FormState>();

  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final seasonNoCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final episodeCountCtrl = TextEditingController();
  DateTime? selectedDate;

  io.File? imageFile;
  html.File? webFile;
  Uint8List? previewBytes;
  String? uploadedImageUrl;
  double uploadProgress = 0;
  bool isLoading = false;

  final castNameCtrl = TextEditingController();
  final castRoleCtrl = TextEditingController();
  String castImageUrl = '';
  Uint8List? castPreview;
  bool isCastUploading = false;

  final crewNameCtrl = TextEditingController();
  final crewRoleCtrl = TextEditingController();
  String crewImageUrl = '';
  Uint8List? crewPreview;
  bool isCrewUploading = false;

  final List<_CastCrewDraft> _castMembers = [];
  final List<_CastCrewDraft> _crewMembers = [];

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    seasonNoCtrl.dispose();
    episodeCountCtrl.dispose();
    amountCtrl.dispose();
    castNameCtrl.dispose();
    castRoleCtrl.dispose();
    crewNameCtrl.dispose();
    crewRoleCtrl.dispose();
    super.dispose();
  }

  void showGlobalSnack(String message) {
    final messenger = globalMessengerKey.currentState;
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> uploadImage(StateSetter setState) async {
    final uri = Uri.parse(ApiConstant.uploadContentImg);
    uploadProgress = 0;

    try {
      if (kIsWeb && webFile != null) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(webFile!);
        await reader.onLoad.first;
        final bytes = Uint8List.fromList((reader.result as List).cast<int>());
        previewBytes = bytes;

        final request = http.MultipartRequest('POST', uri)
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: webFile!.name,
            ),
          );

        final response = await request.send();
        final body = await response.stream.bytesToString();
        final res = ContentImageUploadResponse.fromJson(jsonDecode(body));
        uploadedImageUrl = res.data?.fileUrl;
      } else if (!kIsWeb && imageFile != null) {
        final total = await imageFile!.length();
        int sent = 0;

        final stream = http.ByteStream(
          imageFile!.openRead().transform(
            StreamTransformer.fromHandlers(
              handleData: (List<int> data, EventSink<List<int>> sink) {
                sent += data.length;
                setState(() => uploadProgress = sent / total);
                sink.add(data);
              },
            ),
          ),
        );

        final request = http.MultipartRequest('POST', uri)
          ..files.add(
            http.MultipartFile(
              'file',
              stream,
              total,
              filename: imageFile!.path.split('/').last,
            ),
          );

        final response = await request.send();
        final body = await response.stream.bytesToString();
        final parsed = ContentImageUploadResponse.fromJson(jsonDecode(body));
        uploadedImageUrl = parsed.data?.fileUrl;
      }
    } catch (_) {
      showGlobalSnack("Image upload failed");
    }

    setState(() => uploadProgress = 1);
  }

  Future<void> pickImage(StateSetter setState) async {
    try {
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
            type: ImageValidationType.poster,
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
            type: ImageValidationType.poster,
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
    } catch (_) {
      showGlobalSnack("Failed to pick image");
    }
  }

  Future<void> _pickMemberImage({required bool isCrew}) async {
    if (isCrew ? isCrewUploading : isCastUploading) return;

    try {
      Uint8List bytes;
      String fileName = 'member.jpg';

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
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked == null) return;
        bytes = await io.File(picked.path).readAsBytes();
        fileName = picked.name;
      }

      setState(() {
        if (isCrew) {
          isCrewUploading = true;
          crewPreview = bytes;
        } else {
          isCastUploading = true;
          castPreview = bytes;
        }
      });

      final url = await _uploadMemberImage(bytes, fileName);
      if (url.trim().isNotEmpty) {
        setState(() {
          if (isCrew) {
            crewImageUrl = url;
          } else {
            castImageUrl = url;
          }
        });
      } else {
        showGlobalSnack("Failed to upload image");
      }
    } catch (_) {
      showGlobalSnack("Failed to pick image");
    } finally {
      if (mounted) {
        setState(() {
          if (isCrew) {
            isCrewUploading = false;
          } else {
            isCastUploading = false;
          }
        });
      }
    }
  }

  Future<String> _uploadMemberImage(Uint8List bytes, String filename) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadContentImg),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final parsed = ContentImageUploadResponse.fromJson(jsonDecode(body));
      return parsed.data?.fileUrl?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _addCastMember() {
    final name = castNameCtrl.text.trim();
    final role = castRoleCtrl.text.trim();
    if (name.isEmpty || role.isEmpty) {
      showGlobalSnack("Cast name and role are required.");
      return;
    }
    setState(() {
      _castMembers.add(
        _CastCrewDraft(
          name: name,
          role: role,
          description: '',
          image: castImageUrl.trim(),
          isCrew: false,
        ),
      );
      castNameCtrl.clear();
      castRoleCtrl.clear();
      castImageUrl = '';
      castPreview = null;
    });
  }

  void _addCrewMember() {
    final name = crewNameCtrl.text.trim();
    final role = crewRoleCtrl.text.trim();
    if (name.isEmpty || role.isEmpty) {
      showGlobalSnack("Crew name and role are required.");
      return;
    }
    setState(() {
      _crewMembers.add(
        _CastCrewDraft(
          name: name,
          role: role,
          description: '',
          image: crewImageUrl.trim(),
          isCrew: true,
        ),
      );
      crewNameCtrl.clear();
      crewRoleCtrl.clear();
      crewImageUrl = '';
      crewPreview = null;
    });
  }

  int _extractSeasonId(dynamic jsonData) {
    if (jsonData is Map<String, dynamic>) {
      final directId = jsonData['id'];
      if (directId is int) return directId;
      if (directId is num) return directId.toInt();
      final data = jsonData['data'];
      if (data is Map<String, dynamic>) {
        final dataId = data['id'];
        if (dataId is int) return dataId;
        if (dataId is num) return dataId.toInt();
        final season = data['season'];
        if (season is Map<String, dynamic>) {
          final seasonId = season['id'];
          if (seasonId is int) return seasonId;
          if (seasonId is num) return seasonId.toInt();
        }
      }
    }
    return 0;
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
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(success ? "Season Added" : "Season Failed"),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDate == null) {
      showGlobalSnack("Please select a release date");
      return;
    }
    if (episodeCountCtrl.text.isEmpty) {
      showGlobalSnack("Please add episode count");
      return;
    }
    if (_isDateBeforeToday(selectedDate!)) {
      showGlobalSnack("Release date cannot be before today");
      return;
    }
    if ((uploadedImageUrl ?? '').trim().isEmpty) {
      showGlobalSnack("Please upload season poster");
      return;
    }
    final amount = int.tryParse(amountCtrl.text.trim());
    if (amount == null) {
      showGlobalSnack("Please enter a valid season price");
      return;
    }
    final episodeCount = int.tryParse(episodeCountCtrl.text.trim());
    if (episodeCount == null) {
      showGlobalSnack("Please enter a valid episode count");
      return;
    }
    final seasonNumber = int.tryParse(seasonNoCtrl.text.trim());
    if (seasonNumber == null) {
      showGlobalSnack("Please enter a valid season number");
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = '${ApiConstant.baseUrl}series/${widget.seriesId}/season/add';
      final body = {
        "amount": amount,
        "castIds": [0],
        "description": descCtrl.text.trim(),
        "episodeCount": episodeCount,
        "posterUrl": uploadedImageUrl,
        "releaseDate": DateTime.utc(
          selectedDate!.year,
          selectedDate!.month,
          selectedDate!.day,
        ).toIso8601String(),
        "seasonNumber": seasonNumber,
        "title": titleCtrl.text.trim(),
      };
      final response = await ApiHelper().postApiWithBody(url, body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final parsed = jsonDecode(response.body);
        final seasonId = _extractSeasonId(parsed);
        var resultMessage = _responseMessage(
          response.body,
          "Season added successfully.",
        );

        if (seasonId > 0 &&
            (_castMembers.isNotEmpty || _crewMembers.isNotEmpty)) {
          final members = [..._castMembers, ..._crewMembers];
          if (!mounted) return;
          final provider = Provider.of<SeriesProvider>(context, listen: false);
          final castSaved = await provider.saveSeasonCastCrewMembers(
            contentId: widget.seriesId,
            seasonId: seasonId,
            members: members
                .map((m) => {
                      "name": m.name,
                      "role": m.role,
                      "description": "",
                      "image": m.image,
                      "isCrew": m.isCrew,
                    })
                .toList(growable: false),
          );
          if (!castSaved) {
            resultMessage = "Season created, but cast/crew save failed.";
          }
        }

        if (mounted) setState(() => isLoading = false);
        if (!mounted) return;
        await _showResultDialog(success: true, message: resultMessage);
        if (!mounted) return;
        widget.onSuccess();
        Navigator.of(context).pop();
      } else {
        final message = _responseMessage(
          response.body,
          "Failed to create season.",
        );
        if (mounted) setState(() => isLoading = false);
        if (!mounted) return;
        await _showResultDialog(success: false, message: message);
      }
    } catch (e) {
      debugPrint("Failed: $e");
      if (mounted) setState(() => isLoading = false);
      if (!mounted) return;
      await _showResultDialog(
        success: false,
        message: "Failed to create season.",
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context).getTheme;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        "Add New Season - ${widget.seriesLanguage}",
        style: TextStyle(
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 650,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatefulBuilder(
                  builder: (_, setState) {
                    return GestureDetector(
                      onTap: isLoading ? null : () => pickImage(setState),
                      child: Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.canvasColor),
                          image: previewBytes != null
                              ? DecorationImage(
                                  image: MemoryImage(previewBytes!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: previewBytes == null
                            ? Center(
                                child: Text(
                                  "Upload Poster\n${ImageValidationService.guidelineFor(ImageValidationType.poster)}",
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                if (uploadProgress > 0 && uploadProgress < 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(value: uploadProgress),
                  ),
                const SizedBox(height: 15),
                _field(titleCtrl, "Season Title"),
                _field(descCtrl, "Description", maxLines: 3),
                _field(amountCtrl, "Season Price",
                    keyboard: TextInputType.number),
                _field(episodeCountCtrl, "Episode Count",
                    keyboard: TextInputType.number),
                _field(
                  seasonNoCtrl,
                  "Season Number",
                  keyboard: TextInputType.number,
                ),
                const SizedBox(height: 12),
                _datePicker(theme),
                const SizedBox(height: 16),
                Text(
                  "Cast & Crew Members",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _memberFormCard(
                  theme: theme,
                  title: "Cast",
                  nameCtrl: castNameCtrl,
                  roleCtrl: castRoleCtrl,
                  preview: castPreview,
                  imageUrl: castImageUrl,
                  uploading: isCastUploading,
                  onPickImage: () => _pickMemberImage(isCrew: false),
                  onAdd: _addCastMember,
                ),
                const SizedBox(height: 10),
                _memberList(theme, _castMembers),
                const SizedBox(height: 14),
                _memberFormCard(
                  theme: theme,
                  title: "Crew",
                  nameCtrl: crewNameCtrl,
                  roleCtrl: crewRoleCtrl,
                  preview: crewPreview,
                  imageUrl: crewImageUrl,
                  uploading: isCrewUploading,
                  onPickImage: () => _pickMemberImage(isCrew: true),
                  onAdd: _addCrewMember,
                ),
                const SizedBox(height: 10),
                _memberList(theme, _crewMembers),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Add Season"),
        ),
      ],
    );
  }

  Widget _memberFormCard({
    required ThemeData theme,
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController roleCtrl,
    required Uint8List? preview,
    required String imageUrl,
    required bool uploading,
    required VoidCallback onPickImage,
    required VoidCallback onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _field(nameCtrl, "$title Name", requiredField: false),
          _field(roleCtrl, "$title Role", requiredField: false),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uploading ? null : onPickImage,
                  icon: const Icon(Icons.upload),
                  label: Text(uploading
                      ? "Uploading..."
                      : (imageUrl.trim().isNotEmpty
                          ? "Image Uploaded"
                          : "Upload $title Image")),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onAdd,
                child: Text("Add $title"),
              )
            ],
          ),
          if (preview != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                preview,
                height: 80,
                width: 120,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberList(ThemeData theme, List<_CastCrewDraft> members) {
    if (members.isEmpty) {
      return Text(
        "No members added",
        style: TextStyle(color: theme.canvasColor.withValues(alpha: 0.6)),
      );
    }
    return Column(
      children: members.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 46,
                  width: 46,
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  child: m.image.trim().isNotEmpty
                      ? Image.network(
                          m.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, size: 18),
                        )
                      : const Icon(Icons.person, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${m.name} (${m.role})",
                  style: TextStyle(color: theme.canvasColor),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    members.removeAt(i);
                  });
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              )
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _datePicker(ThemeData theme) {
    final isInvalid = selectedDate != null && _isDateBeforeToday(selectedDate!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isInvalid ? Colors.red : theme.dividerColor,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: theme.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selectedDate == null
                        ? "Select Release Date (Friday only)"
                        : "Release Date: ${DateFormat('dd MMM yyyy').format(selectedDate!)}",
                    style: TextStyle(
                      color: theme.canvasColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  "Change",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isInvalid)
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              "Release date cannot be before today",
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        validator: requiredField
            ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final baseDate = selectedDate == null || _isDateBeforeToday(selectedDate!)
        ? today
        : selectedDate!;
    final daysUntilFriday = (DateTime.friday - baseDate.weekday + 7) % 7;
    final initialDate = baseDate.add(Duration(days: daysUntilFriday));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime(2100),
      selectableDayPredicate: (day) => day.weekday == DateTime.friday,
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  bool _isDateBeforeToday(DateTime value) {
    final v = DateTime(value.year, value.month, value.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return v.isBefore(today);
  }
}

class _CastCrewDraft {
  final String name;
  final String role;
  final String description;
  final String image;
  final bool isCrew;

  _CastCrewDraft({
    required this.name,
    required this.role,
    required this.description,
    required this.image,
    required this.isCrew,
  });
}
