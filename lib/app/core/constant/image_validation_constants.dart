class ImageValidationConstants {
  ImageValidationConstants._();

  // Poster
  static const int posterWidth = 1080;
  static const int posterHeight = 1620;
  static const int posterMinWidth = 720;
  static const int posterMinHeight = 1080;
  static const double posterAspectRatio = 2 / 3;
  static const int posterMaxSizeMB = 2;
  static const int posterMinSizeKB = 50;

  // Banner
  static const int bannerWidth = 1920;
  static const int bannerHeight = 1080;
  static const int bannerMinWidth = 1280;
  static const int bannerMinHeight = 720;
  static const double bannerAspectRatio = 16 / 9;
  static const int bannerMaxSizeMB = 5;

  // TV Banner
  static const int tvBannerWidth = 320;
  static const int tvBannerHeight = 180;

  // Thumbnail
  static const int thumbnailWidth = 1280;
  static const int thumbnailHeight = 720;
  static const int thumbnailMinWidth = 1280;
  static const int thumbnailMinHeight = 720;
  static const double thumbnailAspectRatio = 16 / 9;
  static const int thumbnailMaxSizeMB = 5;

  // Formats
  static const List<String> commonImageFormats = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> tvBannerFormats = ['png'];

  // Messages
  static const String invalidCommonFormat =
      'Only JPG, JPEG, PNG and WEBP images are allowed.';
  static const String invalidTvBannerFormat =
      'TV banner must match the required dimensions and be in PNG format.';
  static const String invalidPosterSize =
      'Poster file size must be between 50 KB and 2 MB.';
  static const String invalidBannerSize =
      'Banner file size must be 5 MB or smaller.';
  static const String invalidThumbnailSize =
      'Thumbnail file size must be 5 MB or smaller.';
  static const String invalidPosterDimensions =
      'Poster width must be at least 720 px and height at least 1080 px. Use an approximate 2:3 aspect ratio (recommended: 1080 x 1620 px) and keep the file between 50 KB and 2 MB.';
  static const String invalidBannerDimensions =
      'Banner width must be at least 1280 px and height at least 720 px. Use an approximate 16:9 aspect ratio (recommended: 1920 x 1080 px) and keep the file at 5 MB or smaller.';
  static const String invalidThumbnailDimensions =
      'Thumbnail width must be at least 1280 px and height at least 720 px. Use an approximate 16:9 aspect ratio and keep the file at 5 MB or smaller.';
  static const String invalidImage = 'Selected file is not a valid image.';

  static String get posterGuideline =>
      'Recommended: $posterWidth x $posterHeight px';
  static String get bannerGuideline =>
      'Recommended: $bannerWidth x $bannerHeight px';
  static String get tvBannerGuideline =>
      'Required Size: $tvBannerWidth x $tvBannerHeight px';
  static String get thumbnailGuideline =>
      'Recommended: $thumbnailWidth x $thumbnailHeight px';
}
