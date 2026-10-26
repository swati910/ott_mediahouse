import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:media_house/app/provider/shorts_provider.dart';
import 'package:media_house/app/widget/custom_textfield.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../../../../data/models/response/content_image_upload_response.dart';
import '../../../../core/constant/api_constant.dart';
import '../../../../core/navigation/app_navigator.dart';
import '../../../../core/utils/image_validation_service.dart';
import '../../../../core/utils/sharepreferences.dart';

class AddShortMaster {
  static const List<String> _rentalDurations = [
    "One Time",
    "One Day",
    "Two Days",
    "Three Days",
    "Seven Days",
    "Two Week",
    "One Month",
  ];

  static void show(BuildContext rootContext) {
    final theme = Theme.of(rootContext);
    final provider = rootContext.read<ShortProvider>();

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final creatorCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final partsCtrl = TextEditingController();
    final coinsCtrl = TextEditingController();
    final rentalDurationCtrl = TextEditingController();
    final castNameCtrl = TextEditingController();
    final castRoleCtrl = TextEditingController();
    final castDescriptionCtrl = TextEditingController();
    final crewNameCtrl = TextEditingController();
    final crewRoleCtrl = TextEditingController();

    bool isTrending = false;
    bool isSubmitting = false;
    bool isCastImageUploading = false;
    bool isCrewImageUploading = false;
    double uploadProgress = 0;
    double castUploadProgress = 0;
    double crewUploadProgress = 0;

    io.File? imageFile;
    html.File? webFile;
    Uint8List? previewBytes;
    String? uploadedImageUrl;
    Uint8List? castPreviewBytes;
    String? castImageUrl;
    Uint8List? crewPreviewBytes;
    String? crewImageUrl;

    final selectedLanguages = <String>[];
    final otherLanguageCtrl = TextEditingController();
    final castList = <Map<String, String>>[];
    final crewList = <Map<String, String>>[];

    // ---------- GLOBAL SNACK ----------
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

    bool hasCastDraft() {
      return castNameCtrl.text.trim().isNotEmpty ||
          castRoleCtrl.text.trim().isNotEmpty ||
          castDescriptionCtrl.text.trim().isNotEmpty ||
          castImageUrl != null;
    }

    void clearCastDraft(StateSetter setState) {
      castNameCtrl.clear();
      castRoleCtrl.clear();
      castDescriptionCtrl.clear();
      setState(() {
        castImageUrl = null;
        castPreviewBytes = null;
        castUploadProgress = 0;
      });
    }

    void addCast(StateSetter setState) {
      final name = castNameCtrl.text.trim();
      final role = castRoleCtrl.text.trim();
      if (name.isEmpty || role.isEmpty) {
        showGlobalSnack("Cast name and role are required.");
        return;
      }

      castList.add({
        "name": name,
        "role": role,
        "description": castDescriptionCtrl.text.trim(),
        "image": castImageUrl ?? '',
      });
      clearCastDraft(setState);
    }

    void addCrew(StateSetter setState) {
      final crewName = crewNameCtrl.text.trim();
      final crewRole = crewRoleCtrl.text.trim();
      if (crewName.isEmpty || crewRole.isEmpty) {
        showGlobalSnack("Crew name and role are required.");
        return;
      }

      setState(() {
        crewList.add({
          "name": crewName,
          "role": crewRole,
          "description": "",
          "image": crewImageUrl ?? '',
        });
        crewNameCtrl.clear();
        crewRoleCtrl.clear();
        crewImageUrl = null;
        crewPreviewBytes = null;
        crewUploadProgress = 0;
      });
    }

    String? uploadedUrlFromBody(String body) {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final data = decoded['data'];
      if (data is String) return data;
      if (data is Map<String, dynamic>) {
        return ContentImageUploadResponse.fromJson(decoded).data?.fileUrl ??
            data['fileUrl']?.toString();
      }
      return null;
    }

    Future<String?> uploadImageBytes({
      required Uint8List bytes,
      required String filename,
    }) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadContentImg),
      )..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      return uploadedUrlFromBody(body);
    }

    // ---------- VALIDATION ----------
    String? validate() {
      if (uploadedImageUrl == null) return "Poster image required";
      if (titleCtrl.text.trim().length < 3) return "Title too short";
      if (descCtrl.text.trim().length < 10) return "Description too short";
      if (creatorCtrl.text.trim().isEmpty) return "Creator required";
      if (categoryCtrl.text.trim().isEmpty) return "Category required";
      if (selectedLanguages.isEmpty) return "Select at least one language";
      if (rentalDurationCtrl.text.trim().isEmpty) {
        return "Rental duration required";
      }
      if (hasCastDraft()) return "Add or clear the current cast draft";
      if (crewNameCtrl.text.trim().isNotEmpty ||
          crewRoleCtrl.text.trim().isNotEmpty ||
          crewImageUrl != null) {
        return "Add or clear the current crew draft";
      }
      if (int.tryParse(partsCtrl.text) == null) return "Invalid parts";
      if ((int.tryParse(partsCtrl.text) ?? 0) <= 0) {
        return "Parts must be greater than 0";
      }
      if (int.tryParse(coinsCtrl.text) == null) return "Invalid price";
      if ((int.tryParse(coinsCtrl.text) ?? -1) < 0) {
        return "Price cannot be negative";
      }
      return null;
    }

    // ---------- UPLOAD IMAGE ----------
    Future<void> uploadImage(StateSetter setState) async {
      final uri = Uri.parse(ApiConstant.uploadContentImg);
      uploadProgress = 0;

      try {
        if (kIsWeb && webFile != null) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(webFile!);
          await reader.onLoad.first;

          final bytes = Uint8List.fromList(reader.result as List<int>);
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
          uploadedImageUrl = uploadedUrlFromBody(body);
        } else if (!kIsWeb && imageFile != null) {
          final total = await imageFile!.length();
          int sent = 0;

          final stream = http.ByteStream(
            imageFile!.openRead().transform(
              StreamTransformer.fromHandlers(
                handleData: (data, sink) {
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
          uploadedImageUrl = uploadedUrlFromBody(body);
        }
      } catch (_) {
        showGlobalSnack("Image upload failed");
      }

      setState(() => uploadProgress = uploadedImageUrl == null ? 0 : 1);
    }

    // ---------- PICK IMAGE ----------
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
            final bytes =
                Uint8List.fromList((reader.result as List).cast<int>());
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

    Future<void> pickCastImage(StateSetter setState) async {
      try {
        if (kIsWeb) {
          final input = html.FileUploadInputElement()..accept = 'image/*';
          input.click();
          input.onChange.listen((_) async {
            if (input.files == null || input.files!.isEmpty) return;
            setState(() {
              isCastImageUploading = true;
              castUploadProgress = 0.2;
            });
            final file = input.files!.first;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;

            final bytes = Uint8List.fromList(reader.result as List<int>);
            final url =
                await uploadImageBytes(bytes: bytes, filename: file.name);
            setState(() {
              castPreviewBytes = bytes;
              castImageUrl = url;
              castUploadProgress = url == null ? 0 : 1;
              isCastImageUploading = false;
            });
          });
        } else {
          setState(() {
            isCastImageUploading = true;
            castUploadProgress = 0.2;
          });
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery);
          if (file == null) {
            setState(() {
              isCastImageUploading = false;
              castUploadProgress = 0;
            });
            return;
          }

          final bytes = await file.readAsBytes();
          final url = await uploadImageBytes(
            bytes: bytes,
            filename: file.name,
          );
          setState(() {
            castPreviewBytes = bytes;
            castImageUrl = url;
            castUploadProgress = url == null ? 0 : 1;
            isCastImageUploading = false;
          });
        }
      } catch (_) {
        setState(() {
          isCastImageUploading = false;
          castUploadProgress = 0;
        });
        showGlobalSnack("Cast image upload failed");
      }
    }

    Future<void> pickCrewImage(StateSetter setState) async {
      try {
        if (kIsWeb) {
          final input = html.FileUploadInputElement()..accept = 'image/*';
          input.click();
          input.onChange.listen((_) async {
            if (input.files == null || input.files!.isEmpty) return;
            setState(() {
              isCrewImageUploading = true;
              crewUploadProgress = 0.2;
            });
            final file = input.files!.first;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoad.first;

            final bytes = Uint8List.fromList(reader.result as List<int>);
            final url =
                await uploadImageBytes(bytes: bytes, filename: file.name);
            setState(() {
              crewPreviewBytes = bytes;
              crewImageUrl = url;
              crewUploadProgress = url == null ? 0 : 1;
              isCrewImageUploading = false;
            });
          });
        } else {
          setState(() {
            isCrewImageUploading = true;
            crewUploadProgress = 0.2;
          });
          final picker = ImagePicker();
          final file = await picker.pickImage(source: ImageSource.gallery);
          if (file == null) {
            setState(() {
              isCrewImageUploading = false;
              crewUploadProgress = 0;
            });
            return;
          }

          final bytes = await file.readAsBytes();
          final url = await uploadImageBytes(
            bytes: bytes,
            filename: file.name,
          );
          setState(() {
            crewPreviewBytes = bytes;
            crewImageUrl = url;
            crewUploadProgress = url == null ? 0 : 1;
            isCrewImageUploading = false;
          });
        }
      } catch (_) {
        setState(() {
          isCrewImageUploading = false;
          crewUploadProgress = 0;
        });
        showGlobalSnack("Crew image upload failed");
      }
    }

    Widget sectionTitle(String title) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: theme.primaryColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    Widget languageSelector(
      BuildContext dialogContext,
      StateSetter setState,
    ) {
      Future<void> openLanguageDialog() async {
        await provider.fetchGroupedLanguages();
        if (!dialogContext.mounted) return;
        final draft = List<String>.from(selectedLanguages);
        final languageOptions = provider.languageOptions;
        final groupedOptions = provider.groupedLanguageOptions;
        otherLanguageCtrl.text =
            draft.where((item) => !languageOptions.contains(item)).join(', ');
        final result = await showDialog<List<String>>(
          context: dialogContext,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, dialogSetState) {
                List<Widget> languageTiles() {
                  final entries = groupedOptions.isEmpty
                      ? {'Languages': languageOptions}.entries
                      : groupedOptions.entries;

                  return entries.expand((entry) {
                    return [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ...entry.value.map((language) {
                        final isSelected = draft.contains(language);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(
                            language,
                            style: TextStyle(color: theme.canvasColor),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: theme.primaryColor,
                          checkColor: Colors.white,
                          onChanged: (checked) {
                            dialogSetState(() {
                              if (checked == true) {
                                draft.add(language);
                              } else {
                                draft.remove(language);
                              }
                            });
                          },
                        );
                      }),
                    ];
                  }).toList();
                }

                return AlertDialog(
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    "Select Languages",
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (provider.isLanguageOptionsLoading)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                          )
                        else if (provider.languageOptionsError != null)
                          Text(
                            provider.languageOptionsError!,
                            style: TextStyle(color: theme.colorScheme.error),
                          )
                        else
                          ...languageTiles(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: otherLanguageCtrl,
                          style: TextStyle(color: theme.canvasColor),
                          decoration: InputDecoration(
                            labelText: "Other language",
                            hintText: "Enter language name",
                            labelStyle: TextStyle(color: theme.canvasColor),
                            hintStyle: TextStyle(
                              color: theme.canvasColor.withValues(alpha: 0.6),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(color: theme.canvasColor),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                      ),
                      onPressed: () {
                        final result = draft
                            .where((item) => languageOptions.contains(item))
                            .toList();
                        final customLanguages = otherLanguageCtrl.text
                            .split(',')
                            .map((item) => item.trim())
                            .where((item) => item.isNotEmpty);
                        for (final language in customLanguages) {
                          if (!result.contains(language)) {
                            result.add(language);
                          }
                        }
                        Navigator.pop(context, result);
                      },
                      child: const Text(
                        "Submit",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (result == null) return;
        setState(() {
          selectedLanguages
            ..clear()
            ..addAll(result);
        });
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Languages"),
          InkWell(
            onTap: isSubmitting ? null : openLanguageDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.inputDecorationTheme.fillColor ??
                    theme.cardColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedLanguages.isEmpty
                          ? "Select Languages"
                          : selectedLanguages.join(", "),
                      style: TextStyle(
                        color: selectedLanguages.isEmpty
                            ? theme.hintColor
                            : theme.canvasColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down, color: theme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget rentalDurationDropdown(StateSetter setState) {
      final selectedValue =
          _rentalDurations.contains(rentalDurationCtrl.text.trim())
              ? rentalDurationCtrl.text.trim()
              : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle("Rental Duration"),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: DropdownButtonFormField<String>(
              value: selectedValue,
              hint: Text(
                "Select Rental Duration",
                style: TextStyle(color: theme.hintColor, fontSize: 14),
              ),
              items: _rentalDurations
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        item,
                        style: TextStyle(
                          color: theme.canvasColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isSubmitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => rentalDurationCtrl.text = value);
                    },
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: theme.cardColor,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
      );
    }

    Widget castSection(StateSetter setState) {
      return Column(
        children: [
          sectionTitle("Cast"),
          CustomTextField(
            controller: castNameCtrl,
            hintText: "Cast Name",
            textInputType: TextInputType.text,
            isValidator: false,
          ),
          CustomTextField(
            controller: castRoleCtrl,
            hintText: "Cast Role",
            textInputType: TextInputType.text,
            isValidator: false,
          ),
          CustomTextField(
            controller: castDescriptionCtrl,
            hintText: "Cast Description",
            maxLine: 2,
            textInputType: TextInputType.text,
            isValidator: false,
          ),
          GestureDetector(
            onTap: isSubmitting || isCastImageUploading
                ? null
                : () => pickCastImage(setState),
            child: Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                image: castPreviewBytes != null
                    ? DecorationImage(
                        image: MemoryImage(castPreviewBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: castPreviewBytes == null
                  ? Center(
                      child: Text(
                        isCastImageUploading
                            ? "Uploading Cast Image..."
                            : "Upload Cast Image",
                        style: TextStyle(color: theme.canvasColor),
                      ),
                    )
                  : null,
            ),
          ),
          if (castUploadProgress > 0 && castUploadProgress < 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: castUploadProgress,
                color: theme.primaryColor,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting ? null : () => addCast(setState),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Cast"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      isSubmitting ? null : () => clearCastDraft(setState),
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear"),
                ),
              ),
            ],
          ),
          if (castList.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate(castList.length, (index) {
              final cast = castList[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${cast["name"] ?? ""} (${cast["role"] ?? ""})",
                  style: TextStyle(color: theme.canvasColor),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() => castList.removeAt(index)),
                ),
              );
            }),
          ],
        ],
      );
    }

    Widget crewSection(StateSetter setState) {
      return Column(
        children: [
          sectionTitle("Crew"),
          CustomTextField(
            controller: crewNameCtrl,
            hintText: "Crew Name",
            textInputType: TextInputType.text,
            isValidator: false,
          ),
          CustomTextField(
            controller: crewRoleCtrl,
            hintText: "Crew Role",
            textInputType: TextInputType.text,
            isValidator: false,
          ),
          GestureDetector(
            onTap: isSubmitting || isCrewImageUploading
                ? null
                : () => pickCrewImage(setState),
            child: Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                image: crewPreviewBytes != null
                    ? DecorationImage(
                        image: MemoryImage(crewPreviewBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: crewPreviewBytes == null
                  ? Center(
                      child: Text(
                        isCrewImageUploading
                            ? "Uploading Crew Image..."
                            : "Upload Crew Image",
                        style: TextStyle(color: theme.canvasColor),
                      ),
                    )
                  : null,
            ),
          ),
          if (crewUploadProgress > 0 && crewUploadProgress < 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                value: crewUploadProgress,
                color: theme.primaryColor,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting ? null : () => addCrew(setState),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Crew"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() {
                            crewNameCtrl.clear();
                            crewRoleCtrl.clear();
                            crewImageUrl = null;
                            crewPreviewBytes = null;
                            crewUploadProgress = 0;
                          }),
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear"),
                ),
              ),
            ],
          ),
          if (crewList.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate(crewList.length, (index) {
              final crew = crewList[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "${crew["name"] ?? ""} (${crew["role"] ?? ""})",
                  style: TextStyle(color: theme.canvasColor),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() => crewList.removeAt(index)),
                ),
              );
            }),
          ],
        ],
      );
    }

    // ---------- UI ----------
    final screenWidth = MediaQuery.of(rootContext).size.width;

    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (dialogContext, setState) {
              return WillPopScope(
                onWillPop: () async => !isSubmitting,
                child: Container(
                  width: screenWidth > 720 ? 620 : screenWidth * 0.9,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// HEADER WITH CLOSE ICON
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Add New Short",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// IMAGE PICKER
                      GestureDetector(
                        onTap: isSubmitting ? null : () => pickImage(setState),
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
                              ? const Center(child: Text("Upload Poster"))
                              : null,
                        ),
                      ),

                      if (uploadProgress > 0 && uploadProgress < 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(
                            value: uploadProgress,
                            color: theme.primaryColor,
                          ),
                        ),

                      const SizedBox(height: 15),

                      languageSelector(dialogContext, setState),

                      CustomTextField(
                          controller: titleCtrl,
                          hintText: "Title",
                          textInputType: TextInputType.text),
                      CustomTextField(
                          controller: descCtrl,
                          hintText: "Description",
                          maxLine: 3,
                          textInputType: TextInputType.text),
                      CustomTextField(
                          controller: creatorCtrl,
                          hintText: "Creator",
                          textInputType: TextInputType.text),
                      CustomTextField(
                          controller: categoryCtrl,
                          hintText: "Category",
                          textInputType: TextInputType.text),
                      rentalDurationDropdown(setState),

                      Row(
                        children: [
                          Expanded(
                              child: CustomTextField(
                                  controller: partsCtrl,
                                  hintText: "Parts",
                                  textInputType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: CustomTextField(
                                  controller: coinsCtrl,
                                  hintText: "Price",
                                  textInputType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Trending",
                            style: TextStyle(color: theme.canvasColor),
                          ),
                          Switch(
                            activeThumbColor: Colors.white,
                            activeTrackColor: theme.primaryColor,
                            value: isTrending,
                            onChanged: isSubmitting
                                ? null
                                : (v) => setState(() => isTrending = v),
                          ),
                        ],
                      ),

                      castSection(setState),
                      crewSection(setState),

                      const SizedBox(height: 20),

                      /// SUBMIT BUTTON WITH LOADER
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final error = validate();
                                if (error != null) {
                                  showGlobalSnack(error);
                                  return;
                                }

                                setState(() => isSubmitting = true);

                                try {
                                  final localSharePreferences =
                                      LocalSharePreferences();
                                  final mediaHouse =
                                      await localSharePreferences.getMediaHouse();

                                  if (mediaHouse == null) {
                                    showGlobalSnack(
                                        "Sorry, Production House is not available.");
                                    return;
                                  }

                                  final nowIso =
                                      DateTime.now().toUtc().toIso8601String();
                                  final body = {
                                    "approvalStatus": "PENDING",
                                    "approvedDateTime": nowIso,
                                    "category": categoryCtrl.text.trim(),
                                    "coinsPerPart": int.parse(coinsCtrl.text),
                                    "creatorName": creatorCtrl.text.trim(),
                                    "crewList": crewList
                                        .map((crew) => crew["name"] ?? "")
                                        .where((name) => name.trim().isNotEmpty)
                                        .toList(),
                                    "description": descCtrl.text.trim(),
                                    "isTrending": isTrending,
                                    "languageList": selectedLanguages
                                        .map(
                                          (language) => {
                                            "fileUrl": "",
                                            "language": language,
                                          },
                                        )
                                        .toList(),
                                    "likeCount": 0,
                                    "mediaHouseId": mediaHouse.id,
                                    "posterUrl": uploadedImageUrl,
                                    "rentlDuration":
                                        rentalDurationCtrl.text.trim(),
                                    "title": titleCtrl.text.trim(),
                                    "totalParts": int.parse(partsCtrl.text),
                                    "uploadDateTime": nowIso,
                                    "viewCount": 0,
                                  };

                                  final createdShort =
                                      await provider.createShortMaster(body);

                                  if (!dialogContext.mounted) return;

                                  if (createdShort == null) {
                                    showGlobalSnack(
                                      "Failed to add short. Check console response.",
                                    );
                                    return;
                                  }

                                  final shortId = createdShort.id;
                                  if (shortId == null || shortId <= 0) {
                                    showGlobalSnack(
                                      "Short saved but short ID not received for cast and crew save.",
                                    );
                                    return;
                                  }

                                  final members = [
                                    ...castList,
                                    ...crewList,
                                  ];
                                  final castCrewSaved =
                                      await provider.saveShortCastCrewMembers(
                                    shortId: shortId,
                                    members: members,
                                  );

                                  if (!dialogContext.mounted) return;

                                  if (!castCrewSaved) {
                                    showGlobalSnack(
                                      "Short saved, but cast and crew save failed.",
                                    );
                                    return;
                                  }

                                  Navigator.of(dialogContext).pop(true);
                                  showGlobalSnack("Short added successfully");
                                } catch (e) {
                                  debugPrint("Add short failed: $e");
                                  showGlobalSnack(
                                    "Failed to add short. Please try again.",
                                  );
                                } finally {
                                  if (dialogContext.mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "Submit",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          ),
        );
      },
    );
  }
}
