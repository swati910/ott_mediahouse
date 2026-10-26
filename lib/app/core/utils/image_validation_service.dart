import 'dart:typed_data';
import 'dart:ui' as ui;

import '../constant/image_validation_constants.dart';

enum ImageValidationType {
  general,
  poster,
  banner,
  thumbnail,
  tvBanner,
}

class ImageValidationResult {
  const ImageValidationResult._({
    required this.isValid,
    this.message,
    this.width,
    this.height,
  });

  factory ImageValidationResult.valid({int? width, int? height}) {
    return ImageValidationResult._(
      isValid: true,
      width: width,
      height: height,
    );
  }

  factory ImageValidationResult.invalid(String message) {
    return ImageValidationResult._(isValid: false, message: message);
  }

  final bool isValid;
  final String? message;
  final int? width;
  final int? height;
}

class ImageValidationService {
  ImageValidationService._();

  static Future<ImageValidationResult> validateBytes({
    required Uint8List bytes,
    required String fileName,
    required ImageValidationType type,
    int? sizeInBytes,
  }) async {
    final extension = _extension(fileName);
    final formatResult = _validateFormat(extension, type);
    if (!formatResult.isValid) return formatResult;

    final fileSize = sizeInBytes ?? bytes.lengthInBytes;
    final sizeResult = _validateSize(fileSize, type);
    if (!sizeResult.isValid) return sizeResult;

    final dimensions = await _readDimensions(bytes);
    if (dimensions == null) {
      return ImageValidationResult.invalid(
        type == ImageValidationType.tvBanner
            ? ImageValidationConstants.invalidTvBannerFormat
            : ImageValidationConstants.invalidImage,
      );
    }

    final dimensionResult = _validateDimensions(
      width: dimensions.width,
      height: dimensions.height,
      type: type,
    );
    if (!dimensionResult.isValid) return dimensionResult;

    return ImageValidationResult.valid(
      width: dimensions.width,
      height: dimensions.height,
    );
  }

  static String guidelineFor(ImageValidationType type) {
    switch (type) {
      case ImageValidationType.general:
        return '';
      case ImageValidationType.poster:
        return ImageValidationConstants.posterGuideline;
      case ImageValidationType.banner:
        return ImageValidationConstants.bannerGuideline;
      case ImageValidationType.thumbnail:
        return ImageValidationConstants.thumbnailGuideline;
      case ImageValidationType.tvBanner:
        return ImageValidationConstants.tvBannerGuideline;
    }
  }

  static ImageValidationResult _validateFormat(
    String extension,
    ImageValidationType type,
  ) {
    if (type == ImageValidationType.tvBanner) {
      return ImageValidationConstants.tvBannerFormats.contains(extension)
          ? ImageValidationResult.valid()
          : ImageValidationResult.invalid(
              ImageValidationConstants.invalidTvBannerFormat,
            );
    }

    return ImageValidationConstants.commonImageFormats.contains(extension)
        ? ImageValidationResult.valid()
        : ImageValidationResult.invalid(
            ImageValidationConstants.invalidCommonFormat,
          );
  }

  static ImageValidationResult _validateSize(
    int sizeInBytes,
    ImageValidationType type,
  ) {
    switch (type) {
      case ImageValidationType.poster:
        final min = ImageValidationConstants.posterMinSizeKB * 1024;
        final max = ImageValidationConstants.posterMaxSizeMB * 1024 * 1024;
        if (sizeInBytes < min || sizeInBytes > max) {
          return ImageValidationResult.invalid(
            'Selected file size is ${_formatFileSize(sizeInBytes)}. '
            '${ImageValidationConstants.invalidPosterSize}',
          );
        }
        return ImageValidationResult.valid();
      case ImageValidationType.banner:
      case ImageValidationType.general:
        if (sizeInBytes >
            ImageValidationConstants.bannerMaxSizeMB * 1024 * 1024) {
          return ImageValidationResult.invalid(
            'Selected file size is ${_formatFileSize(sizeInBytes)}. '
            '${ImageValidationConstants.invalidBannerSize}',
          );
        }
        return ImageValidationResult.valid();
      case ImageValidationType.thumbnail:
        if (sizeInBytes >
            ImageValidationConstants.thumbnailMaxSizeMB * 1024 * 1024) {
          return ImageValidationResult.invalid(
            'Selected file size is ${_formatFileSize(sizeInBytes)}. '
            '${ImageValidationConstants.invalidThumbnailSize}',
          );
        }
        return ImageValidationResult.valid();
      case ImageValidationType.tvBanner:
        return ImageValidationResult.valid();
    }
  }

  static ImageValidationResult _validateDimensions({
    required int width,
    required int height,
    required ImageValidationType type,
  }) {
    switch (type) {
      case ImageValidationType.poster:
      case ImageValidationType.banner:
      case ImageValidationType.thumbnail:
        // Dimensions are recommendations for these images, not upload
        // requirements. A successfully decoded image with an allowed format
        // and file size is accepted.
        return ImageValidationResult.valid();
      case ImageValidationType.tvBanner:
        final exact = width == ImageValidationConstants.tvBannerWidth &&
            height == ImageValidationConstants.tvBannerHeight;
        return exact
            ? ImageValidationResult.valid()
            : ImageValidationResult.invalid(
                ImageValidationConstants.invalidTvBannerFormat,
              );
      case ImageValidationType.general:
        return ImageValidationResult.valid();
    }
  }

  static String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes >= 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(sizeInBytes / 1024).toStringAsFixed(0)} KB';
  }

  static String _extension(String fileName) {
    final cleanName = fileName.split('?').first.toLowerCase();
    final dot = cleanName.lastIndexOf('.');
    if (dot < 0 || dot == cleanName.length - 1) return '';
    return cleanName.substring(dot + 1);
  }

  static Future<_ImageDimensions?> _readDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final dimensions = _ImageDimensions(image.width, image.height);
      image.dispose();
      codec.dispose();
      return dimensions;
    } catch (_) {
      return null;
    }
  }
}

class _ImageDimensions {
  const _ImageDimensions(this.width, this.height);

  final int width;
  final int height;
}
