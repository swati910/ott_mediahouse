import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_validation_service.dart';
import '../../../../provider/videoProvider.dart';
import '../../../widget/multipart_upload_progress_widget.dart';
import '../../../../core/upload/s3_multipart_upload_service.dart';

class UploadMediaHelpers {
  static Widget buildEnhancedUploadSection(
    String label,
    ThemeData selectedThemeData,
    BuildContext context,
  ) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        final bool isUploaded =
            UploadMediaHelpers.getUploadStatus(label, provider);

        final double progress =
            UploadMediaHelpers.getUploadProgress(label, provider);

        final bool isUploading =
            UploadMediaHelpers.getUploadingStatus(label, provider);

        final String? imageUrl =
            UploadMediaHelpers.getImageUrl(label, provider);

        Color containerColor = selectedThemeData.primaryColor.withOpacity(0.1);
        Color borderColor = selectedThemeData.primaryColor.withOpacity(0.3);
        IconData iconData = Icons.cloud_upload_outlined;

        if (isUploaded) {
          containerColor = Colors.green.withOpacity(0.1);
          borderColor = Colors.green.withOpacity(0.3);
          iconData = Icons.check_circle_outline;
        } else if (isUploading) {
          containerColor = selectedThemeData.primaryColor.withOpacity(0.2);
          borderColor = selectedThemeData.primaryColor.withOpacity(0.5);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selectedThemeData.canvasColor,
              ),
            ),
            if (label == "Cast Image" || label == "Crew Image") ...[
              const SizedBox(height: 4),
              Text(
                "Optional",
                style: TextStyle(
                  fontSize: 12,
                  color: selectedThemeData.canvasColor.withOpacity(0.65),
                ),
              ),
            ] else if (isImageFile(label)) ...[
              const SizedBox(height: 4),
              Text(
                ImageValidationService.guidelineFor(ImageValidationType.poster),
                style: TextStyle(
                  fontSize: 12,
                  color: selectedThemeData.canvasColor.withOpacity(0.65),
                ),
              ),
            ],
            const SizedBox(height: 8),
            InkWell(
              onTap: isUploading
                  ? null
                  : () async {
                      if (label == "Movie File" ||
                          label == "Trailer File" ||
                          label == "Teaser File") {
                        await provider.uploadVideoByLabel(label);
                      } else if (label.contains("Audio")) {
                        await provider.pickAudioFile(context, label);
                      } else {
                        await provider.pickImage(label, context);
                      }
                    },
              child: Container(
                height: isUploaded && UploadMediaHelpers.isImageFile(label)
                    ? 120
                    : 80,
                decoration: BoxDecoration(
                  color: containerColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Stack(
                  children: [
                    /// 🔥 LINEAR PROGRESS (ALWAYS SHOW WHEN UPLOADING)
                    if (isUploading)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.green.withOpacity(0.35),
                            ),
                            minHeight: isUploaded &&
                                    UploadMediaHelpers.isImageFile(label)
                                ? 120
                                : 80,
                          ),
                        ),
                      ),

                    /// IMAGE PREVIEW
                    if (isUploaded &&
                        UploadMediaHelpers.isImageFile(label) &&
                        imageUrl != null)
                      UploadMediaHelpers.buildImagePreview(
                          imageUrl, label, selectedThemeData, context)
                    else
                      Center(
                        child: isUploading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    height: 26,
                                    width: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      value: progress.clamp(0.0, 1.0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        selectedThemeData.primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Uploading... ${(progress * 100).toInt()}%",
                                    style: TextStyle(
                                      color: selectedThemeData.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    iconData,
                                    color: isUploaded
                                        ? Colors.green
                                        : selectedThemeData.primaryColor,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      isUploaded
                                          ? (label == "Trailer File"
                                              ? provider.trailerFileName ??
                                                  "$label Uploaded"
                                              : label == "Teaser File"
                                                  ? provider.teaserFileName ??
                                                      "$label Uploaded"
                                                  : provider.movieFileName ??
                                                      "$label Uploaded")
                                          : "Upload $label",
                                      style: TextStyle(
                                        color: isUploaded
                                            ? Colors.green
                                            : selectedThemeData.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (isUploaded) ...[
                                    const SizedBox(width: 8),
                                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                      InkWell(
                                        onTap: () => UploadMediaHelpers.showImagePreview(
                                            context, imageUrl, label, selectedThemeData),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "View",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    InkWell(
                                      onTap: () async {
                                        if (label == "Movie File" ||
                                            label == "Trailer File" ||
                                            label == "Teaser File") {
                                          await provider.uploadVideoByLabel(label);
                                        } else if (label.contains("Audio")) {
                                          await provider.pickAudioFile(context, label);
                                        } else {
                                          await provider.pickImage(label, context);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: selectedThemeData.primaryColor,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "Replace",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => UploadMediaHelpers.deleteMediaByLabel(label, provider),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                  ],
                ),
              ),
            ),
            if (label == "Teaser File" &&
                provider.activeTeaserProgressInfo != null &&
                provider.activeTeaserProgressInfo!.state != MultipartUploadState.idle) ...[
              const SizedBox(height: 12),
              MultipartUploadProgressWidget(
                info: provider.activeTeaserProgressInfo!,
                onPause: () => provider.pauseTeaserMultipartUpload(),
                onResume: () => provider.resumeTeaserMultipartUpload(),
                onRetry: () => provider.retryTeaserMultipartUpload(),
                onAbort: () => provider.abortTeaserMultipartUpload(),
              ),
            ],
            if (label == "Trailer File" &&
                provider.activeTrailerProgressInfo != null &&
                provider.activeTrailerProgressInfo!.state != MultipartUploadState.idle) ...[
              const SizedBox(height: 12),
              MultipartUploadProgressWidget(
                info: provider.activeTrailerProgressInfo!,
                onPause: () => provider.pauseTrailerMultipartUpload(),
                onResume: () => provider.resumeTrailerMultipartUpload(),
                onRetry: () => provider.retryTrailerMultipartUpload(),
                onAbort: () => provider.abortTrailerMultipartUpload(),
              ),
            ],
            if ((label == "Movie File" || label == "Video File") &&
                provider.activePrimaryProgressInfo != null &&
                provider.activePrimaryProgressInfo!.state != MultipartUploadState.idle) ...[
              const SizedBox(height: 12),
              MultipartUploadProgressWidget(
                info: provider.activePrimaryProgressInfo!,
                onPause: () => provider.pausePrimaryMultipartUpload(),
                onResume: () => provider.resumePrimaryMultipartUpload(),
                onRetry: () => provider.retryPrimaryMultipartUpload(),
                onAbort: () => provider.abortPrimaryMultipartUpload(),
              ),
            ],
          ],
        );
      },
    );
  }

  static Widget buildImagePreview(String imageUrl, String label,
      ThemeData themeData, BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
          onError: (exception, stackTrace) {
            print("Error loading image: $exception");
          },
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "$label Uploaded",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => UploadMediaHelpers.showImagePreview(
                          context, imageUrl, label, themeData),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.visibility,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<VideoProvider>(
                      builder: (context, provider, child) {
                        return InkWell(
                          onTap: () async {
                            await provider.pickImage(label, context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeData.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "Replace",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showImagePreview(BuildContext context, String imageUrl,
      String label, ThemeData themeData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Failed to load image",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool isImageFile(String label) {
    return label == "Censor Certificate" ||
        label.startsWith("Poster") ||
        label == "Cast Image" ||
        label == "Crew Image";
  }

  static String? getImageUrl(String label, VideoProvider provider) {
    switch (label) {
      case "Censor Certificate":
        return provider.censorCertificateController.text.isNotEmpty
            ? provider.censorCertificateController.text
            : null;
      case "Poster 1":
        return provider.poster1Controller.text.isNotEmpty
            ? provider.poster1Controller.text
            : null;
      case "Poster 2":
        return provider.poster2Controller.text.isNotEmpty
            ? provider.poster2Controller.text
            : null;
      case "Poster 3":
        return provider.poster3Controller.text.isNotEmpty
            ? provider.poster3Controller.text
            : null;
      case "Cast Image":
        return provider.castImageController.text.isNotEmpty
            ? provider.castImageController.text
            : null;
      case "Crew Image":
        return provider.crewImageController.text.isNotEmpty
            ? provider.crewImageController.text
            : null;
      default:
        return null;
    }
  }

  static void deleteMediaByLabel(String label, VideoProvider provider) {
    switch (label) {
      case "Trailer File":
        provider.trailerUrlController.clear();
        provider.trailerFileName = null;
        provider.trailerUploadProgress = 0.0;
        provider.trailerUploadProgressInfo = null;
        provider.trailerSelectedFile = null;
        provider.trailerUploadTask = null;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['trailer']?.clear();
        }
        break;
      case "Teaser File":
        provider.teaserUrlController.clear();
        provider.teaserFileName = null;
        provider.teaserUploadProgress = 0.0;
        provider.teaserUploadProgressInfo = null;
        provider.teaserSelectedFile = null;
        provider.teaserUploadTask = null;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['teaser']?.clear();
        }
        break;
      case "Movie File":
        provider.movieUrlController.clear();
        provider.movieFileName = null;
        provider.movieUploadProgress = 0.0;
        provider.primaryUploadProgressInfo = null;
        provider.primarySelectedFile = null;
        provider.primaryUploadTask = null;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['movie']?.clear();
        }
        break;
      case "Censor Certificate":
        provider.censorCertificateController.clear();
        provider.censorUploadProgress = 0.0;
        break;
      case "Poster 1":
        provider.poster1Controller.clear();
        provider.poster1UploadProgress = 0.0;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['poster1']?.clear();
        }
        break;
      case "Poster 2":
        provider.poster2Controller.clear();
        provider.poster2UploadProgress = 0.0;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['poster2']?.clear();
        }
        break;
      case "Poster 3":
        provider.poster3Controller.clear();
        provider.poster3UploadProgress = 0.0;
        for (final langMap in provider.movieVariantControllers.values) {
          langMap['poster3']?.clear();
        }
        break;
      case "Cast Image":
        provider.castImageController.clear();
        break;
      case "Crew Image":
        provider.crewImageController.clear();
        break;
      default:
        if (label.endsWith(" Audio")) {
          final language = label.replaceAll(" Audio", "");
          provider.audioControllers[language]?.clear();
        }
        break;
    }
    provider.notifyListeners();
  }

  static bool getUploadStatus(String label, VideoProvider provider) {
    switch (label) {
      case "Trailer File":
        return provider.trailerUrlController.text.isNotEmpty;
      case "Teaser File":
        return provider.teaserUrlController.text.isNotEmpty;
      case "Movie File":
        return provider.movieUrlController.text.isNotEmpty;
      case "Censor Certificate":
        return provider.censorCertificateController.text.isNotEmpty;
      case "Poster 1":
        return provider.poster1Controller.text.isNotEmpty;
      case "Poster 2":
        return provider.poster2Controller.text.isNotEmpty;
      case "Poster 3":
        return provider.poster3Controller.text.isNotEmpty;
      case "Cast Image":
        return provider.castImageController.text.isNotEmpty;
      case "Crew Image":
        return provider.crewImageController.text.isNotEmpty;
      default:
        // Check for dynamically added audio languages
        if (label.endsWith(" Audio")) {
          final language = label.replaceAll(" Audio", "");
          return provider.audioControllers[language]?.text.isNotEmpty ?? false;
        }
        return false;
    }
  }

  static double getUploadProgress(String label, VideoProvider provider) {
    switch (label) {
      case "Trailer File":
        return provider.trailerUploadProgress;
      case "Teaser File":
        return provider.teaserUploadProgress;
      case "Movie File":
        return provider.movieUploadProgress;
      case "Censor Certificate":
      case "Poster 1":
      case "Poster 2":
      case "Poster 3":
        return getUploadStatus(label, provider) ? 1.0 : 0.0;
      case "Cast Image":
        return provider.castImageUploadProgress;
      case "Crew Image":
        return provider.crewImageUploadProgress;
      default:
        // Check for dynamically added audio languages
        if (label.endsWith(" Audio")) {
          return provider.getProgressByLabel(label);
        }
        return 0.0;
    }
  }

  static bool getUploadingStatus(String label, VideoProvider provider) {
    switch (label) {
      case "Trailer File":
        return provider.isTrailerUploading;
      case "Teaser File":
        return provider.isTeaserUploading;
      case "Movie File":
        return provider.isMovieUploading;
      case "Censor Certificate":
      case "Poster 1":
      case "Poster 2":
      case "Poster 3":
      case "Cast Image":
      case "Crew Image":
        return provider.getUploadingStatusByLabel(label);
      default:
        if (label.endsWith(" Audio")) {
          return provider.getUploadingStatusByLabel(label);
        }
        return false;
    }
  }

  static Widget buildDynamicLanguageAudioSection(
      BuildContext context, ThemeData themeData) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (provider.audioLanguages.isEmpty)
              Text(
                'Select languages above to create audio upload sections.',
                style: TextStyle(
                  color: themeData.canvasColor.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
            if (provider.audioLanguages.isNotEmpty) ...[
              ...provider.audioLanguages.map((language) {
                return Column(
                  children: [
                    UploadMediaHelpers.buildAudioUploadSection(
                      "$language Audio",
                      themeData,
                      context,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  static void showAddAudioLanguageDialog(
      BuildContext context, VideoProvider provider, ThemeData themeData) {
    final TextEditingController languageController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: themeData.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Audio Language',
            style: TextStyle(
              color: themeData.primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the language name for the audio file',
                style: TextStyle(
                  color: themeData.canvasColor.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: languageController,
                decoration: InputDecoration(
                  hintText: 'e.g., Hindi, English, Tamil',
                  hintStyle: TextStyle(
                    color: themeData.canvasColor.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: themeData.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: themeData.primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: themeData.scaffoldBackgroundColor,
                ),
                style: TextStyle(color: themeData.canvasColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: themeData.canvasColor.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final language = languageController.text.trim();
                if (language.isNotEmpty) {
                  provider.addAudioLanguage(context, language);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: themeData.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget buildAudioUploadSection(
      String label, ThemeData selectedThemeData, BuildContext context) {
    return Consumer<VideoProvider>(builder: (context, provider, child) {
      bool isUploaded = UploadMediaHelpers.getUploadStatus(label, provider);
      double progress = UploadMediaHelpers.getUploadProgress(label, provider);
      bool isUploading = UploadMediaHelpers.getUploadingStatus(label, provider);

      Color containerColor = selectedThemeData.primaryColor.withOpacity(0.1);
      Color borderColor = selectedThemeData.primaryColor.withOpacity(0.3);
      IconData iconData = Icons.audiotrack_outlined;
      if (isUploaded) {
        containerColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green.withOpacity(0.3);
        iconData = Icons.check_circle_outline;
      } else if (isUploading) {
        containerColor = selectedThemeData.primaryColor.withOpacity(0.2);
        borderColor = selectedThemeData.primaryColor.withOpacity(0.5);
        iconData = Icons.audiotrack_outlined;
      }
      String? uploadedFileName;
      if (isUploaded) {
        // Attempt to get the file name from the controller
        if (label.endsWith(" Audio")) {
          final language = label.replaceAll(" Audio", "");
          uploadedFileName =
              provider.audioControllers[language]?.text.split('/').last;
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                size: 16,
                color: selectedThemeData.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selectedThemeData.canvasColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: isUploading
                ? null
                : () async {
                    await provider.pickAudioFile(context, label);
                  },
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Stack(
                children: [
                  if (isUploading && progress > 0)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              selectedThemeData.primaryColor.withOpacity(0.3),
                            ),
                            minHeight: 80,
                          ),
                        ),
                      ),
                    ),
                  Center(
                    child: isUploading
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  value: progress > 0 ? progress : null,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    selectedThemeData.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                progress > 0
                                    ? "Uploading... ${(progress * 100).toInt()}%"
                                    : "Preparing...",
                                style: TextStyle(
                                  color: selectedThemeData.primaryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                iconData,
                                color: isUploaded
                                    ? Colors.green
                                    : selectedThemeData.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      isUploaded
                                          ? (uploadedFileName ??
                                              "$label Uploaded")
                                          : "Upload $label",
                                      style: TextStyle(
                                        color: isUploaded
                                            ? Colors.green
                                            : selectedThemeData.primaryColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (!isUploaded)
                                      Text(
                                        "Supported: MP3, WAV, AAC",
                                        style: TextStyle(
                                          color: selectedThemeData.canvasColor
                                              .withOpacity(0.6),
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (isUploaded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      uploadedFileName ?? "Audio file uploaded successfully",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => UploadMediaHelpers.showAudioPreview(
                        context, label, provider), // Pass context
                    icon: Icon(
                      Icons.play_circle_outline,
                      color: Colors.green,
                      size: 20,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Logic to clear the uploaded audio file
                      if (label.endsWith(" Audio")) {
                        final language = label.replaceAll(" Audio", "");
                        provider.clearAudioFile(language);
                      }
                    },
                    icon: Icon(
                      Icons.close,
                      color: Colors.red,
                      size: 20,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  static void showAudioPreview(
      BuildContext context, String label, VideoProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Audio Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.audiotrack,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Audio file is ready for playback',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Implement audio playback functionality here
                Navigator.of(context).pop();
              },
              child: Text('Play Audio'),
            ),
          ],
        );
      },
    );
  }
}
