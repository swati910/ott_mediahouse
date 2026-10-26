import 'dart:async';
import 'dart:io';
import 'dart:io' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:media_house/data/models/request/save_series_request.dart';
import 'package:media_house/data/models/response/allContentResponse.dart';
import 'package:media_house/data/models/response/content_image_upload_response.dart';
import 'package:media_house/data/models/response/image_upload_response.dart';
import 'package:media_house/data/models/response/language_group_response.dart';
import 'package:media_house/data/models/response/video_upload_response.dart';
import 'package:media_house/data/models/response/audio_upload_response.dart';
import 'package:universal_html/html.dart' as html;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_house/app/widget/get_date_time.dart';
import 'package:media_house/data/models/request/moviePrcentageRequest.dart';
import 'package:media_house/data/models/response/addVideoResponse.dart';
import 'package:media_house/data/models/response/getAllMediaHouseResponse.dart';
import 'package:media_house/data/models/response/graphResponse.dart';
import 'package:media_house/data/models/response/searchResponse.dart';
import 'package:universal_html/js.dart';
import 'package:media_house/data/models/response/audience_analytics_response.dart';
import 'package:media_house/data/models/response/content_revenue_breakdown_response.dart';
import 'package:media_house/data/models/response/purchased_users_response.dart';
import 'dart:convert';
import '../../data/models/request/content_request.dart';
import '../../data/models/response/getAllUserResponse.dart';
import '../../data/models/response/getContentResponse.dart';
import '../../domain/entities/content.dart';
import '../../domain/entities/mediaHouse.dart';
import '../../domain/entities/user.dart';
import '../core/auth/auth_service.dart';
import '../core/constant/api_constant.dart';
import '../core/constant/image_validation_constants.dart';
import '../core/network/api_helper.dart';
import '../core/utils/image_validation_service.dart';
import '../core/utils/sharepreferences.dart';
import '../widget/show_toast.dart';
import '../core/utils/user_message.dart';
import '../core/utils/currency_formatter.dart';
import '../core/upload/multipart_upload_persistence.dart';
import '../core/upload/s3_multipart_upload_service.dart';
import 'dart:typed_data';

class VideoProvider extends ChangeNotifier {
  VideoProvider() : super() {
    searchContentController.addListener(filterContent);
  }
  Timer? _searchDebounce;

  // ===========================
  // PAGINATION PROPERTIES (MINIMAL)
  // ===========================
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;
  bool _isLoadingMore = false;
  bool _hasMoreItems = true;
  int _mediaHouseCurrentPage = 0;
  int _mediaHouseTotalPages = 0;
  int? _mediaHouseIdForPagination;
  String _mediaHouseTypeForPagination = "MOVIE";
  String _mediaHouseKeywordForPagination = "";
  bool _isMediaHouseLoadingMore = false;
  bool _hasMoreMediaHouseItems = true;
  int _statusCurrentPage = 0;
  int _statusTotalPages = 0;
  int? _statusMediaHouseIdForPagination;
  String _statusValueForPagination = "ALL";
  String _statusTypeForPagination = "MOVIE";
  String _statusKeywordForPagination = "";
  String? _statusStartDateForPagination;
  String? _statusEndDateForPagination;
  bool _isStatusLoadingMore = false;
  bool _hasMoreStatusItems = true;
  int _releasedCurrentPage = 0;
  int _releasedTotalPages = 0;
  int? _releasedMediaHouseId;
  String _releasedTypeForPagination = "MOVIE";
  String _releasedKeywordForPagination = "";
  String? _releasedStartDateForPagination;
  String? _releasedEndDateForPagination;
  bool _isReleasedLoadingMore = false;
  bool _hasMoreReleasedItems = true;

  // Getters for pagination
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => _totalItems;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreItems => _hasMoreItems;
  bool get isMediaHouseLoadingMore => _isMediaHouseLoadingMore;
  bool get hasMoreMediaHouseItems => _hasMoreMediaHouseItems;
  bool get isStatusLoadingMore => _isStatusLoadingMore;
  bool get hasMoreStatusItems => _hasMoreStatusItems;
  bool get isReleasedLoadingMore => _isReleasedLoadingMore;
  bool get hasMoreReleasedItems => _hasMoreReleasedItems;

  // Setter to change items per page
  void setItemsPerPage(int items) {
    _itemsPerPage = items;
    resetPagination();
    notifyListeners();
  }

  TextEditingController searchContentController = TextEditingController();
  final TextEditingController videoController = TextEditingController();
  final TextEditingController ageRatingController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController movieUrlController = TextEditingController();
  final TextEditingController teaserUrlController = TextEditingController();
  bool _isSavingContent = false;
  bool get isSavingContent => _isSavingContent;

  final TextEditingController trailerUrlController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController releaseDateController = TextEditingController();
  final TextEditingController rentlDurationController = TextEditingController();
  final TextEditingController censorCertificateController =
      TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();

  String? _activeContentId;
  String? get activeContentId => _activeContentId;
  set activeContentId(String? val) {
    _activeContentId = val;
    notifyListeners();
  }

  html.File? primarySelectedFile;
  S3MultipartUploadTask? primaryUploadTask;
  MultipartProgressInfo? primaryUploadProgressInfo;

  html.File? teaserSelectedFile;
  S3MultipartUploadTask? teaserUploadTask;
  MultipartProgressInfo? teaserUploadProgressInfo;

  html.File? trailerSelectedFile;
  S3MultipartUploadTask? trailerUploadTask;
  MultipartProgressInfo? trailerUploadProgressInfo;

  S3MultipartUploadTask? get activePrimaryUploadTask => primaryUploadTask;
  MultipartProgressInfo? get activePrimaryProgressInfo => primaryUploadProgressInfo;

  S3MultipartUploadTask? get activeTeaserUploadTask => teaserUploadTask;
  MultipartProgressInfo? get activeTeaserProgressInfo => teaserUploadProgressInfo;

  S3MultipartUploadTask? get activeTrailerUploadTask => trailerUploadTask;
  MultipartProgressInfo? get activeTrailerProgressInfo => trailerUploadProgressInfo;

  Future<void> startPrimaryMultipartUpload({
    required html.File file,
    required String contentId,
    required String taskId,
    String? language,
    String? field,
  }) async {
    primarySelectedFile = file;
    movieFileName = file.name;
    _isMovieUploading = true;
    movieUploadProgress = 0.01;
    if (language != null && field != null) {
      final variantKey = _movieVariantKey(language, field);
      _movieVariantUploading[variantKey] = true;
      _movieVariantUploadProgress[variantKey] = 0.01;
    }
    notifyListeners();

    primaryUploadTask = S3MultipartUploadTask(
      localTaskId: taskId,
      file: file,
      contentId: contentId,
      onProgress: (info) {
        primaryUploadProgressInfo = info;
        movieUploadProgress = (info.percentage / 100.0).clamp(0.0, 1.0);
        _isMovieUploading = (info.state == MultipartUploadState.initiating ||
            info.state == MultipartUploadState.uploading ||
            info.state == MultipartUploadState.completing ||
            info.state == MultipartUploadState.resuming);

        if (language != null && field != null) {
          final variantKey = _movieVariantKey(language, field);
          _movieVariantUploading[variantKey] = _isMovieUploading;
          _movieVariantUploadProgress[variantKey] = movieUploadProgress;
        }

        if (info.state == MultipartUploadState.completed) {
          final finalUrl = (primaryUploadTask?.videoUrl.isNotEmpty == true)
              ? primaryUploadTask!.videoUrl
              : (info.videoUrl.isNotEmpty
                  ? info.videoUrl
                  : (primaryUploadTask?.key ?? ''));
          if (finalUrl.isNotEmpty) {
            movieUrlController.text = finalUrl;
            if (language != null && field != null) {
              movieVariantController(language, field).text = finalUrl;
            } else {
              for (final langMap in _movieVariantControllers.values) {
                if (langMap.containsKey('movie')) {
                  langMap['movie']!.text = finalUrl;
                }
              }
            }
          }
          _isMovieUploading = false;
          if (language != null && field != null) {
            final variantKey = _movieVariantKey(language, field);
            _movieVariantUploading[variantKey] = false;
            _movieVariantUploadProgress[variantKey] = 1.0;
          }
        }
        notifyListeners();
      },
    );

    await primaryUploadTask!.startOrResume();
  }

  Future<void> startTeaserMultipartUpload({
    required html.File file,
    required String contentId,
    required String taskId,
    String? language,
    String? field,
  }) async {
    teaserSelectedFile = file;
    teaserFileName = file.name;
    _isTeaserUploading = true;
    teaserUploadProgress = 0.01;
    notifyListeners();

    teaserUploadTask = S3MultipartUploadTask(
      localTaskId: taskId,
      file: file,
      contentId: contentId,
      onProgress: (info) {
        teaserUploadProgressInfo = info;
        teaserUploadProgress = (info.percentage / 100.0).clamp(0.0, 1.0);
        _isTeaserUploading = (info.state == MultipartUploadState.initiating ||
            info.state == MultipartUploadState.uploading ||
            info.state == MultipartUploadState.completing ||
            info.state == MultipartUploadState.resuming);

        if (info.state == MultipartUploadState.completed) {
          final finalUrl = (teaserUploadTask?.videoUrl.isNotEmpty == true)
              ? teaserUploadTask!.videoUrl
              : (info.videoUrl.isNotEmpty
                  ? info.videoUrl
                  : (teaserUploadTask?.key ?? ''));
          if (finalUrl.isNotEmpty) {
            teaserUrlController.text = finalUrl;
            if (language != null && field != null) {
              movieVariantController(language, field).text = finalUrl;
            } else {
              for (final langMap in _movieVariantControllers.values) {
                if (langMap.containsKey('teaser')) {
                  langMap['teaser']!.text = finalUrl;
                }
              }
            }
          }
          _isTeaserUploading = false;
        }
        notifyListeners();
      },
    );

    await teaserUploadTask!.startOrResume();
  }

  Future<void> startTrailerMultipartUpload({
    required html.File file,
    required String contentId,
    required String taskId,
    String? language,
    String? field,
  }) async {
    trailerSelectedFile = file;
    trailerFileName = file.name;
    _isTrailerUploading = true;
    trailerUploadProgress = 0.01;
    notifyListeners();

    trailerUploadTask = S3MultipartUploadTask(
      localTaskId: taskId,
      file: file,
      contentId: contentId,
      onProgress: (info) {
        trailerUploadProgressInfo = info;
        trailerUploadProgress = (info.percentage / 100.0).clamp(0.0, 1.0);
        _isTrailerUploading = (info.state == MultipartUploadState.initiating ||
            info.state == MultipartUploadState.uploading ||
            info.state == MultipartUploadState.completing ||
            info.state == MultipartUploadState.resuming);

        if (info.state == MultipartUploadState.completed) {
          final finalUrl = (trailerUploadTask?.videoUrl.isNotEmpty == true)
              ? trailerUploadTask!.videoUrl
              : (info.videoUrl.isNotEmpty
                  ? info.videoUrl
                  : (trailerUploadTask?.key ?? ''));
          if (finalUrl.isNotEmpty) {
            trailerUrlController.text = finalUrl;
            if (language != null && field != null) {
              movieVariantController(language, field).text = finalUrl;
            } else {
              for (final langMap in _movieVariantControllers.values) {
                if (langMap.containsKey('trailer')) {
                  langMap['trailer']!.text = finalUrl;
                }
              }
            }
          }
          _isTrailerUploading = false;
        }
        notifyListeners();
      },
    );

    await trailerUploadTask!.startOrResume();
  }

  void pausePrimaryMultipartUpload() {
    primaryUploadTask?.pause();
  }

  Future<void> resumePrimaryMultipartUpload({html.File? file}) async {
    final targetFile = file ?? primarySelectedFile;
    if (targetFile != null && primaryUploadTask != null) {
      primaryUploadTask!.updateFileHandle(targetFile);
    }
    await primaryUploadTask?.startOrResume();
  }

  Future<void> retryPrimaryMultipartUpload({html.File? file}) async {
    final targetFile = file ?? primarySelectedFile;
    if (targetFile != null && primaryUploadTask != null) {
      primaryUploadTask!.updateFileHandle(targetFile);
    }
    await primaryUploadTask?.startOrResume();
  }

  Future<void> abortPrimaryMultipartUpload() async {
    await primaryUploadTask?.abort();
    primaryUploadTask = null;
    primaryUploadProgressInfo = null;
    primarySelectedFile = null;
    movieUploadProgress = 0.0;
    _isMovieUploading = false;
    movieUrlController.clear();
    notifyListeners();
  }

  void pauseTeaserMultipartUpload() => teaserUploadTask?.pause();
  Future<void> resumeTeaserMultipartUpload() async => teaserUploadTask?.startOrResume();
  Future<void> retryTeaserMultipartUpload() async => teaserUploadTask?.startOrResume();
  Future<void> abortTeaserMultipartUpload() async {
    await teaserUploadTask?.abort();
    teaserUploadTask = null;
    teaserUploadProgressInfo = null;
    teaserSelectedFile = null;
    teaserUploadProgress = 0.0;
    _isTeaserUploading = false;
    teaserUrlController.clear();
    notifyListeners();
  }

  void pauseTrailerMultipartUpload() => trailerUploadTask?.pause();
  Future<void> resumeTrailerMultipartUpload() async => trailerUploadTask?.startOrResume();
  Future<void> retryTrailerMultipartUpload() async => trailerUploadTask?.startOrResume();
  Future<void> abortTrailerMultipartUpload() async {
    await trailerUploadTask?.abort();
    trailerUploadTask = null;
    trailerUploadProgressInfo = null;
    trailerSelectedFile = null;
    trailerUploadProgress = 0.0;
    _isTrailerUploading = false;
    trailerUrlController.clear();
    notifyListeners();
  }
  
  final TextEditingController typeController = TextEditingController();
  final TextEditingController runTimeController = TextEditingController();
  final TextEditingController numberOfAttemptController =
      TextEditingController();
  final TextEditingController fullAttemptController = TextEditingController();
  final TextEditingController poster1Controller = TextEditingController();
  final TextEditingController poster2Controller = TextEditingController();
  final TextEditingController poster3Controller = TextEditingController();
  final TextEditingController castController = TextEditingController();
  final TextEditingController directorController = TextEditingController();
  final TextEditingController castNameController = TextEditingController();
  final TextEditingController castRoleController = TextEditingController();
  final TextEditingController castDescriptionController =
      TextEditingController();
  final TextEditingController castImageController = TextEditingController();
  final TextEditingController crewNameController = TextEditingController();
  final TextEditingController crewRoleController = TextEditingController();
  final TextEditingController crewImageController = TextEditingController();
  final TextEditingController rentalDurationController =
      TextEditingController();
  final TextEditingController registrationFeeDetailsController =
      TextEditingController();
  final TextEditingController registrationPaymentIdController =
      TextEditingController();
  final TextEditingController registrationPaymentDateController =
      TextEditingController();
  final TextEditingController registrationAmountPaidController =
      TextEditingController();
  final TextEditingController registrationPlanTypeController =
      TextEditingController();
  final TextEditingController registrationValidityController =
      TextEditingController();
  final TextEditingController registrationPaymentMethodController =
      TextEditingController();
  final TextEditingController agreementDocumentUrlController =
      TextEditingController();
  final TextEditingController agreementSignedDateController =
      TextEditingController();
  final List<Map<String, String>> _pendingCasts = [];
  List<Map<String, String>> get pendingCasts =>
      List.unmodifiable(_pendingCasts);
  final List<Map<String, String>> _pendingCrews = [];
  List<Map<String, String>> get pendingCrews =>
      List.unmodifiable(_pendingCrews);

  bool isEnbale = false;
  List<Content> _contentList = [];
  List<Content> _filteredContentList = [];
  Content? _content = Content();
  Content _selectedContent = Content();
  List<Map<String, dynamic>> _contentCastList = [];

  List<Content> get contentList => _contentList;
  List<Content> get filteredContentList => _filteredContentList;
  Content? get content => _content;
  Content get selectedContent => _selectedContent;
  List<Map<String, dynamic>> get contentCastList =>
      List.unmodifiable(_contentCastList);

  List<String> _selectedItems = [];
  List<String> get selectedItems => _selectedItems;
  List<String> _selectedGeners = [];
  List<String> get selectedGeners => _selectedGeners;
  List<String> _selectedAudioFormat = [];
  List<String> get selectedAudioFormat => _selectedAudioFormat;
  List<LanguageList> _selectedLanguages = [];
  List<LanguageList> get selectedLanguages => _selectedLanguages;
  Map<String, List<String>> _groupedLanguageOptions = {};
  Map<String, List<String>> get groupedLanguageOptions =>
      Map.unmodifiable(_groupedLanguageOptions);
  List<String> get languageOptions => _groupedLanguageOptions.values
      .expand((items) => items)
      .where((item) => item.trim().isNotEmpty)
      .toSet()
      .toList();
  bool _isLanguageOptionsLoading = false;
  bool get isLanguageOptionsLoading => _isLanguageOptionsLoading;
  String? _languageOptionsError;
  String? get languageOptionsError => _languageOptionsError;
  Future<void>? _languageOptionsRequest;
  List<String> _selectedSubLanguages = [];
  List<String> get selectedSubLanguages => _selectedSubLanguages;
  List<String> _castList = [];
  List<String> get castList => _castList;
  List<String> _directorList = [];
  List<String> get directorList => _directorList;

  // Progress tracking for all upload types
  double trailerUploadProgress = 0.0;
  double teaserUploadProgress = 0.0;
  double movieUploadProgress = 0.0;
  double censorUploadProgress = 0.0;
  double poster1UploadProgress = 0.0;
  double poster2UploadProgress = 0.0;
  double poster3UploadProgress = 0.0;
  double castImageUploadProgress = 0.0;
  double crewImageUploadProgress = 0.0;

  // Individual uploading status for each file type
  bool _isTrailerUploading = false;
  bool _isTeaserUploading = false;
  bool _isMovieUploading = false;
  bool _isCensorUploading = false;
  bool _isPoster1Uploading = false;
  bool _isPoster2Uploading = false;
  bool _isPoster3Uploading = false;
  bool _isCastImageUploading = false;
  bool _isCrewImageUploading = false;

  // Getters for uploading status
  bool get isTrailerUploading => _isTrailerUploading;
  bool get isTeaserUploading => _isTeaserUploading;
  bool get isMovieUploading => _isMovieUploading;
  bool get isCensorUploading => _isCensorUploading;
  bool get isPoster1Uploading => _isPoster1Uploading;
  bool get isPoster2Uploading => _isPoster2Uploading;
  bool get isPoster3Uploading => _isPoster3Uploading;
  bool get isCastImageUploading => _isCastImageUploading;
  bool get isCrewImageUploading => _isCrewImageUploading;

  // Dynamic audio language controllers and lists
  final Map<String, TextEditingController> audioControllers = {};
  final List<String> _audioLanguages = [];
  List<String> get audioLanguages => _audioLanguages;
  final Map<String, Map<String, TextEditingController>>
      _movieVariantControllers = {};
  Map<String, Map<String, TextEditingController>> get movieVariantControllers =>
      _movieVariantControllers;
  final Map<String, int> _movieVariantDurations = {};
  final Map<String, double> _movieVariantUploadProgress = {};
  final Map<String, bool> _movieVariantUploading = {};

  // Specific upload statuses and progress for dynamic audio files
  final Map<String, double> _audioUploadProgress = {};
  final Map<String, bool> _isAudioUploading = {};

  // ===========================
  // PAGINATION METHODS (MINIMAL)
  // ===========================

  /// Reset pagination to initial state
  void resetPagination() {
    _currentPage = 1;
    _hasMoreItems = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load next page of items
  void loadNextPage() {
    if (!_isLoadingMore && _hasMoreItems) {
      _isLoadingMore = true;
      notifyListeners();

      Future.delayed(Duration(milliseconds: 300), () {
        _currentPage++;
        _updateHasMoreItems();
        _isLoadingMore = false;
        notifyListeners();
      });
    }
  }

  /// Load next page based on an externally filtered total count.
  Future<void> loadNextPageForCount(int totalCount) async {
    if (_isLoadingMore) return;

    if ((_currentPage * _itemsPerPage) >= totalCount) {
      _hasMoreItems = false;
      notifyListeners();
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));
    _currentPage++;
    _hasMoreItems = (_currentPage * _itemsPerPage) < totalCount;
    _isLoadingMore = false;
    notifyListeners();
  }

  /// Load previous page
  void loadPreviousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      _updateHasMoreItems();
      notifyListeners();
    }
  }

  /// Jump to specific page
  void jumpToPage(int pageNumber) {
    final maxPages = getTotalPages();
    if (pageNumber > 0 && pageNumber <= maxPages) {
      _currentPage = pageNumber;
      _updateHasMoreItems();
      notifyListeners();
    }
  }

  /// Update whether more items are available
  void _updateHasMoreItems() {
    final endIndex = _currentPage * _itemsPerPage;
    _hasMoreItems = endIndex < _filteredContentList.length;
  }

  /// Get all items up to current page (for infinite scroll)
  List<Content> getAllItemsUpToCurrentPage() {
    final endIndex = _currentPage * _itemsPerPage;
    if (_filteredContentList.isEmpty) return [];

    return _filteredContentList.sublist(
      0,
      endIndex > _filteredContentList.length
          ? _filteredContentList.length
          : endIndex,
    );
  }

  /// Get visible item count up to current page for custom filtered lists.
  int visibleCountFor(int totalCount) {
    if (totalCount <= 0) return 0;
    final endIndex = _currentPage * _itemsPerPage;
    return endIndex > totalCount ? totalCount : endIndex;
  }

  /// Whether more items are available for custom filtered lists.
  bool hasMoreForCount(int totalCount) {
    return visibleCountFor(totalCount) < totalCount;
  }

  /// Get current page number
  int getCurrentPageNumber() => _currentPage;

  /// Get total number of pages
  int getTotalPages() {
    if (_filteredContentList.isEmpty) return 0;
    return (_filteredContentList.length / _itemsPerPage).ceil();
  }

  /// Get page info as string
  String getPageInfo() {
    int totalPages = getTotalPages();
    return "Page $_currentPage of $totalPages";
  }

  /// Helper method to get uploading status by label
  bool getUploadStatus(String label) {
    switch (label) {
      case "Trailer File":
        return trailerUrlController.text.isNotEmpty;
      case "Teaser File":
        return teaserUrlController.text.isNotEmpty;
      case "Movie File":
        return movieUrlController.text.isNotEmpty;
      case "Censor Certificate":
        return censorCertificateController.text.isNotEmpty;
      case "Poster 1":
        return poster1Controller.text.isNotEmpty;
      case "Poster 2":
        return poster2Controller.text.isNotEmpty;
      case "Poster 3":
        return poster3Controller.text.isNotEmpty;
      case "Cast Image":
        return castImageController.text.isNotEmpty;
      case "Crew Image":
        return crewImageController.text.isNotEmpty;
      default:
        if (label.endsWith(" Audio")) {
          final language = label.replaceAll(" Audio", "");
          return audioControllers[language]?.text.isNotEmpty ?? false;
        }
        return false;
    }
  }

  // Merged helper method to get uploading status by label for all file types
  bool getUploadingStatusByLabel(String label) {
    switch (label) {
      case "Trailer File":
        return _isTrailerUploading;
      case "Teaser File":
        return _isTeaserUploading;
      case "Movie File":
        return _isMovieUploading;
      case "Censor Certificate":
        return _isCensorUploading;
      case "Poster 1":
        return _isPoster1Uploading;
      case "Poster 2":
        return _isPoster2Uploading;
      case "Poster 3":
        return _isPoster3Uploading;
      case "Cast Image":
        return _isCastImageUploading;
      case "Crew Image":
        return _isCrewImageUploading;
      default:
        if (label.endsWith(" Audio")) {
          final language = label.replaceAll(" Audio", "");
          return _isAudioUploading[language] ?? false;
        }
        return false;
    }
  }

  // Merged helper method to get upload progress by label for all file types
  double getProgressByLabel(String label) {
    if (label == "Trailer File") {
      return trailerUploadProgress;
    } else if (label == "Teaser File") {
      return teaserUploadProgress;
    } else if (label == "Movie File") {
      return movieUploadProgress;
    } else if (label == "Censor Certificate" || label.startsWith("Poster")) {
      return getUploadStatus(label) ? 1.0 : 0.0;
    } else if (label == "Cast Image") {
      return castImageUploadProgress;
    } else if (label == "Crew Image") {
      return crewImageUploadProgress;
    } else if (label.endsWith(" Audio")) {
      final language = label.replaceAll(" Audio", "");
      return _audioUploadProgress[language] ?? 0.0;
    }
    return 0.0;
  }

  // Helper method to set uploading status by label
  void _setUploadingStatus(String label, bool status) {
    switch (label) {
      case "Trailer File":
        _isTrailerUploading = status;
        break;
      case "Teaser File":
        _isTeaserUploading = status;
        break;
      case "Movie File":
        _isMovieUploading = status;
        break;
      case "Censor Certificate":
        _isCensorUploading = status;
        break;
      case "Poster 1":
        _isPoster1Uploading = status;
        break;
      case "Poster 2":
        _isPoster2Uploading = status;
        break;
      case "Poster 3":
        _isPoster3Uploading = status;
        break;
      case "Cast Image":
        _isCastImageUploading = status;
        break;
      case "Crew Image":
        _isCrewImageUploading = status;
        break;
    }
  }

  // Helper method to set progress by label
  void _setProgressByLabel(String label, double progress) {
    switch (label) {
      case "Trailer File":
        trailerUploadProgress = progress;
        break;
      case "Teaser File":
        teaserUploadProgress = progress;
        break;
      case "Movie File":
        movieUploadProgress = progress;
        break;
      case "Censor Certificate":
        censorUploadProgress = progress;
        break;
      case "Poster 1":
        poster1UploadProgress = progress;
        break;
      case "Poster 2":
        poster2UploadProgress = progress;
        break;
      case "Poster 3":
        poster3UploadProgress = progress;
        break;
      case "Cast Image":
        castImageUploadProgress = progress;
        break;
      case "Crew Image":
        crewImageUploadProgress = progress;
        break;
    }
  }

  void addValuesToList(String label) {
    if (label == "Cast") {
      if (castController.text.trim().isNotEmpty) {
        _castList.addAll(
          castController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
        castController.clear();
      }
    } else if (label == "Director") {
      if (directorController.text.trim().isNotEmpty) {
        _directorList.addAll(
          directorController.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
        directorController.clear();
      }
    }
    print("Cast List: $_castList");
    print("Director List: $_directorList");
    notifyListeners();
  }

  void removeValue(String value) {
    _castList.remove(value);
  }

  void toggleSelection(String item, String label) {
    if (label == "Genres") {
      if (selectedGeners.contains(item)) {
        selectedGeners.remove(item);
      } else {
        selectedGeners.add(item);
      }
    } else if (label == "Audio Formats") {
      if (selectedAudioFormat.contains(item)) {
        selectedAudioFormat.remove(item);
      } else {
        selectedAudioFormat.add(item);
      }
    } else if (label == "Subtitle Languages") {
      if (selectedSubLanguages.contains(item)) {
        selectedSubLanguages.remove(item);
      } else {
        selectedSubLanguages.add(item);
      }
    } else if (label == "Languages" || label == "Audio Languages") {
      final existingIndex = selectedLanguages
          .indexWhere((language) => (language.language ?? "") == item);
      if (existingIndex >= 0) {
        selectedLanguages.removeAt(existingIndex);
      } else {
        selectedLanguages.add(LanguageList(language: item, fileUrl: ''));
      }
      _syncAudioLanguagesWithSelectedLanguages();
    }
    notifyListeners();
  }

  void dropDownSelection(String item, String label) {
    if (label == "Age Rating") {
      ageRatingController.text = item;
    } else if (label == "Type") {
      typeController.text = item;
    } else if (label == "Rental Duration") {
      rentalDurationController.text = item;
      rentlDurationController.text = item;
    }
    notifyListeners();
  }

  void clearSelections() {
    _selectedItems.clear();
    notifyListeners();
  }

  bool _isDownloadable = true;
  bool get isDownloadable => _isDownloadable;

  void toggleDownloadable(bool value) {
    _isDownloadable = value;
    notifyListeners();
  }

  bool _isRegistrationFeePaid = false;
  bool get isRegistrationFeePaid => _isRegistrationFeePaid;
  String get registrationFeePaidValue => _isRegistrationFeePaid ? "Y" : "N";
  String get registrationFeeDetailsValue => _composeRegistrationFeeDetails();
  double? _activeRegistrationFee;
  double? get activeRegistrationFee => _activeRegistrationFee;
  String? _activeRegistrationFeeContentType;
  String? get activeRegistrationFeeContentType =>
      _activeRegistrationFeeContentType;
  String? _activeRegistrationFeeAudienceScope;
  String? get activeRegistrationFeeAudienceScope =>
      _activeRegistrationFeeAudienceScope;
  String? _activeRegistrationFeeRemarks;
  String? get activeRegistrationFeeRemarks => _activeRegistrationFeeRemarks;
  bool _isRegistrationFeeLoading = false;
  bool get isRegistrationFeeLoading => _isRegistrationFeeLoading;
  String? _registrationFeeError;
  String? get registrationFeeError => _registrationFeeError;
  bool _isAgreementUploading = false;
  bool get isAgreementUploading => _isAgreementUploading;
  double _agreementUploadProgress = 0.0;
  double get agreementUploadProgress => _agreementUploadProgress;
  String? _agreementFileName;
  String? get agreementFileName => _agreementFileName;
  String get agreementDocumentUrl => agreementDocumentUrlController.text.trim();
  String get agreementSignedDate => agreementSignedDateController.text.trim();
  bool get hasUploadedAgreement => agreementDocumentUrl.isNotEmpty;
  bool get hasCompletedAgreementWorkflow =>
      hasUploadedAgreement && _isRegistrationFeePaid;
  String get isReadyForApprovalValue =>
      hasCompletedAgreementWorkflow ? "Y" : "N";
  String get derivedApprovalStatus {
    final isPaid = registrationFeePaidValue == "Y";
    final hasFeeDetails = registrationFeeDetailsValue.trim().isNotEmpty;
    return isPaid && hasFeeDetails ? "PENDING" : "PENDING";
  }

  String get activeRegistrationFeeText {
    final fee = _activeRegistrationFee;
    if (fee == null) return '';
    return formatAmount(fee);
  }

  double? _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> fetchActiveRegistrationFeeRule({
    required String contentType,
    String audienceScope = "INDIA",
  }) async {
    final normalizedType = contentType.trim().toUpperCase();
    if (normalizedType.isEmpty) return;

    _isRegistrationFeeLoading = true;
    _registrationFeeError = null;
    _activeRegistrationFee = null;
    _activeRegistrationFeeContentType = normalizedType;
    _activeRegistrationFeeAudienceScope = audienceScope;
    registrationAmountPaidController.clear();
    registrationFeeDetailsController.text = registrationFeeDetailsValue;
    notifyListeners();

    try {
      final apiUrl = ApiConstant.activeRegistrationFeeRule(
        contentType: normalizedType,
        audienceScope: audienceScope,
      );
      final response = await ApiHelper().getApi(apiUrl);
      final responseBody = json.decode(response.body) as Map<String, dynamic>;
      final data = responseBody["data"];
      final rule =
          data is Map<String, dynamic> ? data["registrationFeeRule"] : null;
      if (response.statusCode != 200 || rule is! Map<String, dynamic>) {
        _registrationFeeError =
            responseBody["message"]?.toString() ?? "Registration fee not found";
        return;
      }

      final fee = _readDouble(rule["registrationFee"]);
      if (fee == null || fee <= 0) {
        _registrationFeeError = "Registration fee not found";
        return;
      }

      _activeRegistrationFee = fee;
      _activeRegistrationFeeContentType =
          rule["contentType"]?.toString() ?? normalizedType;
      _activeRegistrationFeeAudienceScope =
          rule["audienceScope"]?.toString() ?? audienceScope;
      _activeRegistrationFeeRemarks = rule["remarks"]?.toString();
      registrationAmountPaidController.text = activeRegistrationFeeText;
      registrationFeeDetailsController.text = registrationFeeDetailsValue;
    } catch (error) {
      debugPrint("Registration fee fetch failed: $error");
      _registrationFeeError = "Unable to fetch registration fee";
    } finally {
      _isRegistrationFeeLoading = false;
      notifyListeners();
    }
  }

  void toggleRegistrationFeePaid(bool value) {
    _isRegistrationFeePaid = value;
    registrationFeeDetailsController.text = registrationFeeDetailsValue;
    notifyListeners();
  }

  void setRegistrationPaymentDetails({
    required String paymentId,
    required String paymentDate,
    required String amountPaid,
    required String planType,
    required String validity,
    required String paymentMethod,
    bool markPaid = true,
  }) {
    registrationPaymentIdController.text = paymentId.trim();
    registrationPaymentDateController.text = paymentDate.trim();
    registrationAmountPaidController.text = amountPaid.trim();
    registrationPlanTypeController.text = planType.trim();
    registrationValidityController.text = validity.trim();
    registrationPaymentMethodController.text = paymentMethod.trim();
    if (markPaid) {
      _isRegistrationFeePaid = true;
    }
    registrationFeeDetailsController.text = registrationFeeDetailsValue;
    notifyListeners();
  }

  void clearRegistrationPaymentDetails({bool markUnpaid = true}) {
    registrationPaymentIdController.clear();
    registrationPaymentDateController.clear();
    registrationAmountPaidController.clear();
    registrationPlanTypeController.clear();
    registrationValidityController.clear();
    registrationPaymentMethodController.clear();
    if (markUnpaid) {
      _isRegistrationFeePaid = false;
    }
    registrationFeeDetailsController.text = registrationFeeDetailsValue;
    notifyListeners();
  }

  String _composeRegistrationFeeDetails() {
    return [
      "Payment ID: ${registrationPaymentIdController.text.trim()}",
      "Payment Date: ${registrationPaymentDateController.text.trim()}",
      "Amount Paid: ${registrationAmountPaidController.text.trim()}",
      "Plan Type: ${registrationPlanTypeController.text.trim()}",
      "Validity: ${registrationValidityController.text.trim()}",
      "Payment Method: ${registrationPaymentMethodController.text.trim()}",
      "Agreement Upload URL: ${agreementDocumentUrlController.text.trim()}",
      "Agreement Signed Date: ${agreementSignedDateController.text.trim()}",
      "Agreement Uploaded: ${hasUploadedAgreement ? 'Y' : 'N'}",
    ].join("; ");
  }

  void _populateRegistrationFeeDetailsFields(String details) {
    registrationPaymentIdController.clear();
    registrationPaymentDateController.clear();
    registrationAmountPaidController.clear();
    registrationPlanTypeController.clear();
    registrationValidityController.clear();
    registrationPaymentMethodController.clear();
    agreementDocumentUrlController.clear();
    agreementSignedDateController.clear();
    _agreementFileName = null;

    final text = details.trim();
    if (text.isEmpty) return;

    String? extract(String key) {
      final regExp = RegExp('$key:' r'\s*([^;]+)');
      final match = regExp.firstMatch(text);
      return match == null ? null : match.group(1)?.trim();
    }

    final paymentId = extract("Payment ID");
    final paymentDate = extract("Payment Date");
    final amountPaid = extract("Amount Paid");
    final planType = extract("Plan Type");
    final validity = extract("Validity");
    final paymentMethod = extract("Payment Method");
    final agreementUploadUrl = extract("Agreement Upload URL");
    final agreementSignedDate = extract("Agreement Signed Date");

    if (paymentId != null ||
        paymentDate != null ||
        amountPaid != null ||
        planType != null ||
        validity != null ||
        paymentMethod != null ||
        agreementUploadUrl != null ||
        agreementSignedDate != null) {
      registrationPaymentIdController.text = paymentId ?? '';
      registrationPaymentDateController.text = paymentDate ?? '';
      registrationAmountPaidController.text = amountPaid ?? '';
      registrationPlanTypeController.text = planType ?? '';
      registrationValidityController.text = validity ?? '';
      registrationPaymentMethodController.text = paymentMethod ?? '';
      agreementDocumentUrlController.text = agreementUploadUrl ?? '';
      agreementSignedDateController.text = agreementSignedDate ?? '';
      if (agreementUploadUrl != null && agreementUploadUrl.trim().isNotEmpty) {
        final uri = Uri.tryParse(agreementUploadUrl.trim());
        final segments = uri?.pathSegments ?? const <String>[];
        _agreementFileName =
            segments.isEmpty ? null : Uri.decodeComponent(segments.last);
      }
      return;
    }

    registrationPaymentIdController.text = text;
  }

  bool _isFeatured = false;
  bool get isFeatured => _isFeatured;

  void toggleFeatured(bool value) {
    _isFeatured = value;
    notifyListeners();
  }

  void filterContent() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _applyFilterWithoutReset();
    });
  }

  Future<void> _applyFilterWithoutReset() async {
    final query = searchContentController.text.trim();

    try {
      if (_releasedMediaHouseId != null) {
        await fetchReleasedMoviesByMediaHouseId(
          _releasedMediaHouseId!,
          type: _releasedTypeForPagination,
          searchKeyword: query,
          startDate: _releasedStartDateForPagination,
          endDate: _releasedEndDateForPagination,
        );
        return;
      }

      if (_statusMediaHouseIdForPagination != null) {
        await fetchMoviesByStatusAndMediaHouseId(
          _statusValueForPagination,
          _statusMediaHouseIdForPagination!,
          type: _statusTypeForPagination,
          searchKeyword: query,
          startDate: _statusStartDateForPagination,
          endDate: _statusEndDateForPagination,
        );
        return;
      }

      if (_mediaHouseIdForPagination != null) {
        await fetchMoviesByMediaHouseId(
          _mediaHouseIdForPagination!,
          type: _mediaHouseTypeForPagination,
          searchKeyword: query,
        );
        return;
      }
    } catch (error) {
      debugPrint("Search API failed, falling back to local filter: $error");
    }

    // Fallback when no pagination context exists.
    final localQuery = query.toLowerCase();
    _filteredContentList = _contentList.where((content) {
      final title = (content.title ?? "").toLowerCase();
      final ageRating = (content.ageRating ?? "").toLowerCase();
      final description = (content.description ?? "").toLowerCase();
      final type = (content.type ?? "").toLowerCase();

      return title.contains(localQuery) ||
          ageRating.contains(localQuery) ||
          description.contains(localQuery) ||
          type.contains(localQuery);
    }).toList();
    _totalItems = _filteredContentList.length;
    resetPagination();
    notifyListeners();
  }

  List<Content> _mergeContentWithoutDuplicates(
      List<Content> current, List<Content> incoming) {
    if (incoming.isEmpty) return current;
    final merged = List<Content>.from(current);
    final existingIds = <String>{};
    for (int i = 0; i < current.length; i++) {
      final item = current[i];
      final key = item.id != null
          ? item.id.toString()
          : "${item.title ?? ''}-${item.releaseDate ?? ''}-$i";
      existingIds.add(key);
    }
    for (int i = 0; i < incoming.length; i++) {
      final item = incoming[i];
      final key = item.id != null
          ? item.id.toString()
          : "${item.title ?? ''}-${item.releaseDate ?? ''}-$i";
      if (!existingIds.contains(key)) {
        merged.add(item);
        existingIds.add(key);
      }
    }
    return merged;
  }

  String _formatDateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  setSelectedContent(Content content) {
    _selectedContent = content;
    searchContentController.clear();
    notifyListeners();
  }

  // Fetch movies by Production house with pagination.
  Future<void> fetchMoviesByMediaHouseId(
    int mediaHouseId, {
    String type = "MOVIE",
    String? searchKeyword,
    int page = 0,
    bool loadMore = false,
  }) async {
    final normalizedKeyword = (searchKeyword ?? "").trim();
    if (!loadMore) {
      _mediaHouseIdForPagination = mediaHouseId;
      _mediaHouseTypeForPagination = type;
      _mediaHouseKeywordForPagination = normalizedKeyword;
      _mediaHouseCurrentPage = 0;
      _mediaHouseTotalPages = 0;
      _hasMoreMediaHouseItems = true;
      _isMediaHouseLoadingMore = false;
    }

    final apiUrl = ApiConstant.getVideoByMediaHouseId(
      mediaHouseId,
      type: type,
      searchKeyword: normalizedKeyword,
      page: page,
      size: _itemsPerPage,
    );
    debugPrint(apiUrl);

    ApiHelper apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body) as Map<String, dynamic>;
        final allContentResponse = AllContentResponse.fromJson(responseBody);
        final data = allContentResponse.data;
        final fetchedContent = data?.contentList ?? [];

        if (allContentResponse.success == true) {
          _mediaHouseCurrentPage = data?.currentPage ?? page;
          _mediaHouseTotalPages = data?.totalPages ?? 0;
          _hasMoreMediaHouseItems = _mediaHouseTotalPages > 0
              ? (_mediaHouseCurrentPage + 1) < _mediaHouseTotalPages
              : fetchedContent.length >= _itemsPerPage;

          _contentList = loadMore
              ? _mergeContentWithoutDuplicates(_contentList, fetchedContent)
              : List<Content>.from(fetchedContent);
          _filteredContentList = List<Content>.from(_contentList);
          _totalItems = data?.totalItems ?? _filteredContentList.length;
          _hasMoreItems = _hasMoreMediaHouseItems;
          notifyListeners();
        } else {
          if (!loadMore) {
            _contentList.clear();
            _filteredContentList.clear();
            _totalItems = 0;
          }
          _hasMoreMediaHouseItems = false;
          _hasMoreItems = false;
          notifyListeners();
        }
      } else {
        if (!loadMore) {
          _contentList.clear();
          _filteredContentList.clear();
          _totalItems = 0;
        }
        _hasMoreMediaHouseItems = false;
        _hasMoreItems = false;
        notifyListeners();
        throw Exception(
            'Failed to fetch Content. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _hasMoreMediaHouseItems = false;
      _hasMoreItems = false;
      notifyListeners();
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching Content.');
    }
  }

  Future<void> fetchNextMoviesByMediaHousePage() async {
    if (_mediaHouseIdForPagination == null ||
        _isMediaHouseLoadingMore ||
        !_hasMoreMediaHouseItems) {
      return;
    }
    _isMediaHouseLoadingMore = true;
    notifyListeners();
    try {
      await fetchMoviesByMediaHouseId(
        _mediaHouseIdForPagination!,
        type: _mediaHouseTypeForPagination,
        searchKeyword: _mediaHouseKeywordForPagination,
        page: _mediaHouseCurrentPage + 1,
        loadMore: true,
      );
    } finally {
      _isMediaHouseLoadingMore = false;
      notifyListeners();
    }
  }

  // Fetch movies by status and Production house with pagination.
  Future<void> fetchMoviesByStatusAndMediaHouseId(
    String status,
    int mediaHouseId, {
    String type = "MOVIE",
    String? searchKeyword,
    String? startDate,
    String? endDate,
    int page = 0,
    bool loadMore = false,
  }) async {
    final normalizedStatus = status.toUpperCase();
    final normalizedKeyword = (searchKeyword ?? "").trim();
    final normalizedType = type.toUpperCase();
    final effectiveStartDate = startDate?.trim();
    final effectiveEndDate = endDate?.trim();

    if (!loadMore) {
      _statusMediaHouseIdForPagination = mediaHouseId;
      _statusValueForPagination = normalizedStatus;
      _statusTypeForPagination = normalizedType;
      _statusKeywordForPagination = normalizedKeyword;
      _statusStartDateForPagination =
          (effectiveStartDate?.isNotEmpty ?? false) ? effectiveStartDate : null;
      _statusEndDateForPagination =
          (effectiveEndDate?.isNotEmpty ?? false) ? effectiveEndDate : null;
      _statusCurrentPage = 0;
      _statusTotalPages = 0;
      _hasMoreStatusItems = true;
      _isStatusLoadingMore = false;
      _isLoadingMore = false;
    } else {
      _isLoadingMore = true;
      _isStatusLoadingMore = true;
      notifyListeners();
    }

    final apiUrl = ApiConstant.filterAdvancedContent(
      mediaHouseId: mediaHouseId,
      type: normalizedType,
      approvalStatus: normalizedStatus,
      startDate:
          (effectiveStartDate?.isNotEmpty ?? false) ? effectiveStartDate : null,
      endDate:
          (effectiveEndDate?.isNotEmpty ?? false) ? effectiveEndDate : null,
      searchKeyword: normalizedKeyword,
      page: page,
      size: _itemsPerPage,
    );
    debugPrint(apiUrl);

    ApiHelper apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body) as Map<String, dynamic>;
        final allContentResponse = AllContentResponse.fromJson(responseBody);
        final data = allContentResponse.data;
        final fetchedContent = data?.contentList ?? [];

        if (allContentResponse.success == true) {
          _statusCurrentPage = data?.currentPage ?? page;
          _statusTotalPages = data?.totalPages ?? 0;
          _hasMoreStatusItems = _statusTotalPages > 0
              ? (_statusCurrentPage + 1) < _statusTotalPages
              : fetchedContent.length >= _itemsPerPage;

          _contentList = loadMore
              ? _mergeContentWithoutDuplicates(_contentList, fetchedContent)
              : List<Content>.from(fetchedContent);
          _filteredContentList = List<Content>.from(_contentList);
          _totalItems = data?.totalItems ?? _filteredContentList.length;
          _hasMoreItems = _hasMoreStatusItems;
          notifyListeners();
        } else {
          if (!loadMore) {
            _contentList.clear();
            _filteredContentList.clear();
            _totalItems = 0;
          }
          _hasMoreStatusItems = false;
          _hasMoreItems = false;
          notifyListeners();
        }
      } else if (response.statusCode == 404 && !loadMore) {
        _contentList.clear();
        _filteredContentList.clear();
        _totalItems = 0;
        _hasMoreStatusItems = false;
        _hasMoreItems = false;
        notifyListeners();
      } else {
        throw Exception(
            'Failed to fetch Content. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _hasMoreStatusItems = false;
      _hasMoreItems = false;
      notifyListeners();
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching Content.');
    } finally {
      _isLoadingMore = false;
      _isStatusLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextMoviesByStatusAndMediaHousePage() async {
    if (_statusMediaHouseIdForPagination == null ||
        _isStatusLoadingMore ||
        !_hasMoreStatusItems) {
      return;
    }
    await fetchMoviesByStatusAndMediaHouseId(
      _statusValueForPagination,
      _statusMediaHouseIdForPagination!,
      type: _statusTypeForPagination,
      searchKeyword: _statusKeywordForPagination,
      startDate: _statusStartDateForPagination,
      endDate: _statusEndDateForPagination,
      page: _statusCurrentPage + 1,
      loadMore: true,
    );
  }

  // Fetch released movies by Production house with pagination.
  Future<void> fetchReleasedMoviesByMediaHouseId(
    int mediaHouseId, {
    String type = "MOVIE",
    String? searchKeyword,
    String? startDate,
    String? endDate,
    int page = 0,
    bool loadMore = false,
  }) async {
    final normalizedType = type.toUpperCase();
    final normalizedKeyword = (searchKeyword ?? "").trim();
    final effectiveStartDate =
        startDate ?? _formatDateOnly(DateTime(DateTime.now().year, 1, 1));
    final effectiveEndDate = endDate ?? _formatDateOnly(DateTime.now());
    if (!loadMore) {
      _releasedMediaHouseId = mediaHouseId;
      _releasedTypeForPagination = normalizedType;
      _releasedKeywordForPagination = normalizedKeyword;
      _releasedStartDateForPagination = effectiveStartDate;
      _releasedEndDateForPagination = effectiveEndDate;
      _releasedCurrentPage = 0;
      _releasedTotalPages = 0;
      _hasMoreReleasedItems = true;
      _isReleasedLoadingMore = false;
    }

    final apiUrl = ApiConstant.filterAdvancedContent(
      mediaHouseId: mediaHouseId,
      type: normalizedType,
      approvalStatus: "APPROVED",
      startDate: effectiveStartDate,
      endDate: effectiveEndDate,
      searchKeyword: normalizedKeyword,
      page: page,
      size: _itemsPerPage,
    );
    debugPrint("get movie response api::: $apiUrl");
    ApiHelper apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body) as Map<String, dynamic>;
        final getAllContentResponse = AllContentResponse.fromJson(responseBody);
        final releasedData = getAllContentResponse.data;
        final fetchedContent = releasedData?.contentList ?? [];

        if (getAllContentResponse.success == true) {
          _releasedCurrentPage = releasedData?.currentPage ?? page;
          _releasedTotalPages = releasedData?.totalPages ?? 0;
          _hasMoreReleasedItems = _releasedTotalPages > 0
              ? (_releasedCurrentPage + 1) < _releasedTotalPages
              : fetchedContent.length >= _itemsPerPage;

          _contentList = loadMore
              ? _mergeContentWithoutDuplicates(_contentList, fetchedContent)
              : List<Content>.from(fetchedContent);
          _filteredContentList = List<Content>.from(_contentList);
          _totalItems = releasedData?.totalItems ?? _filteredContentList.length;
          notifyListeners();
        } else {
          if (!loadMore) {
            _contentList.clear();
            _filteredContentList.clear();
            _totalItems = 0;
          }
          _hasMoreReleasedItems = false;
          notifyListeners();
        }
      } else {
        if (!loadMore) {
          _contentList.clear();
          _filteredContentList.clear();
          _totalItems = 0;
        }
        _hasMoreReleasedItems = false;
        notifyListeners();
        throw Exception(
            'Failed to fetch released content. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _hasMoreReleasedItems = false;
      notifyListeners();
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching Content.');
    }
  }

  Future<void> fetchNextReleasedMoviesPage() async {
    if (_releasedMediaHouseId == null ||
        _isReleasedLoadingMore ||
        !_hasMoreReleasedItems) {
      return;
    }

    _isReleasedLoadingMore = true;
    notifyListeners();
    try {
      await fetchReleasedMoviesByMediaHouseId(
        _releasedMediaHouseId!,
        type: _releasedTypeForPagination,
        searchKeyword: _releasedKeywordForPagination,
        startDate: _releasedStartDateForPagination,
        endDate: _releasedEndDateForPagination,
        page: _releasedCurrentPage + 1,
        loadMore: true,
      );
    } catch (error) {
      debugPrint("Error fetching next released content page: $error");
    } finally {
      _isReleasedLoadingMore = false;
      notifyListeners();
    }
  }

  // Fetch all moviesByStatusAndMediaHouseId
  Future<void> changeContentStatus(context, String status, int id) async {
    String apiUrl = ApiConstant.changeContentStatus(status, id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.putApi(apiUrl);
      debugPrint("response::: " + response.body);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        _content = Content.fromJson(responseBody);
        CustomToast.show(
            context, "Content '${status.toLowerCase()}' successfully",
            isSuccess: true);
        notifyListeners();
      } else {
        throw Exception(
            'Failed to fetch Content. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching Content.');
    }
  }

  Future<Content?> uploadContent(BuildContext context) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    if (mediaHouse == null) {
      CustomToast.show(context, "Production house not found.",
          isSuccess: false);
      return null;
    }

    Availability availability = Availability();
    DateTime now = DateTime.now();
    String isoDate = now.toUtc().toIso8601String();
    String apiUrl = ApiConstant.saveVideo;

    SaveContentRequest saveContent = SaveContentRequest();
    saveContent.id = 0;
    saveContent.ageRating = ageRatingController.text;
    saveContent.aggrementDocument = agreementDocumentUrl;
    saveContent.approvalStatus = derivedApprovalStatus;
    saveContent.approvedDateTime = '';
    saveContent.audioFormatList = selectedAudioFormat;
    saveContent.availability = availability;
    saveContent.castList = castList;
    saveContent.contentUrl = movieUrlController.text;
    saveContent.directorList = directorList;
    saveContent.description = descriptionController.text;
    saveContent.genersList = selectedGeners;
    saveContent.isAggrement = hasUploadedAgreement;
    saveContent.isDownloadable = isDownloadable;
    saveContent.isFeatured = isFeatured;
    saveContent.isPaid = isRegistrationFeePaid;
    saveContent.isReadyForApproval = isReadyForApprovalValue;
    saveContent.registrationFeePaid = registrationFeePaidValue;
    saveContent.registrationFeeDetails = registrationFeeDetailsValue;
    saveContent.languageList = selectedLanguages;
    saveContent.mediaHouseId = mediaHouse.id!;
    saveContent.price = double.tryParse(priceController.text) ?? 0.0;
    saveContent.posterUrlList = [
      poster1Controller.text,
      poster2Controller.text,
      poster3Controller.text,
    ];
    saveContent.ratings = 0;
    saveContent.ratingCount = 0;
    saveContent.reason = '';
    saveContent.releaseDate = releaseDateController.text;
    saveContent.releaseTime = '';
    saveContent.rentlDuration = rentalDurationController.text.isNotEmpty
        ? rentalDurationController.text
        : rentlDurationController.text;
    saveContent.totalRevenue = 0;
    saveContent.runtime = double.tryParse(runTimeController.text) ?? 0.0;
    saveContent.numberOfAttempt =
        int.tryParse(numberOfAttemptController.text.trim()) ?? 0;
    saveContent.fullAttempt =
        int.tryParse(fullAttemptController.text.trim()) ?? 0;
    saveContent.subtitleLanguageList = selectedSubLanguages;
    saveContent.sensorCertificate = censorCertificateController.text;
    saveContent.type = typeController.text;
    saveContent.title = titleController.text;
    saveContent.teaserUrl = teaserUrlController.text;
    saveContent.trailerUrl = trailerUrlController.text;
    saveContent.uploadDateTime = isoDate;
    saveContent.views = 0;

    ApiHelper apiHelper = ApiHelper();
    try {
      final payload = saveContent.toJson();
      debugPrint("Payload: ${json.encode(payload)}");
      var response = await apiHelper.postApiWithBody(apiUrl, payload);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final addVideoResponse = AddVideoResponse.fromJson(responseBody);
        if (addVideoResponse.isSuccess == true) {
          Content contentObj = addVideoResponse.data!;
          _activeContentId = contentObj.id?.toString();
          if (primarySelectedFile != null &&
              (primaryUploadTask == null ||
                  primaryUploadTask!.state == MultipartUploadState.idle ||
                  primaryUploadTask!.state == MultipartUploadState.failed)) {
            startPrimaryMultipartUpload(
              file: primarySelectedFile!,
              contentId: contentObj.id.toString(),
              taskId: 'primary_${contentObj.id}',
            );
          }
          CustomToast.show(
            context,
            UserMessage.resolve(
              apiMessage: addVideoResponse.message,
              fallbackMessage:
                  'Video added successfully. Complete the agreement step to send it for admin approval.',
            ),
            isSuccess: true,
          );
          fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
          notifyListeners();
          return contentObj;
        } else {
          debugPrint(
              "Error: ${addVideoResponse.message ?? 'Record not added'}");
          CustomToast.show(
              context,
              UserMessage.resolve(
                  apiMessage: addVideoResponse.message,
                  fallbackMessage:
                      'Unable to add the content. Please try again.'),
              isSuccess: false);
          return null;
        }
      } else {
        debugPrint("Failed: ${response.statusCode}, ${response.body}");
        CustomToast.show(
            context,
            UserMessage.forStatus(response.statusCode,
                fallbackMessage:
                    'Unable to add the content. Please try again.'),
            isSuccess: false);
      }
    } catch (error) {
      debugPrint("Error: $error");
      CustomToast.show(
          context,
          UserMessage.forException(error,
              fallbackMessage: 'Unable to add the content. Please try again.'),
          isSuccess: false);
    }
    return null;
  }

  Future<Content?> uploadSeries(BuildContext context) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    if (mediaHouse == null) {
      CustomToast.show(context, "Production house not found.",
          isSuccess: false);
      return null;
    }

    Availability availability = Availability();
    DateTime now = DateTime.now();
    String isoDate = now.toUtc().toIso8601String();
    String apiUrl = ApiConstant.saveSeries;

    SaveSeriesRequest saveContent = SaveSeriesRequest();
    saveContent.audioFormatList = [];
    saveContent.availability = availability;
    saveContent.directorList = directorList;
    saveContent.description = descriptionController.text;
    saveContent.aggrementDocument = agreementDocumentUrl;
    saveContent.isAggrement = hasUploadedAgreement;
    saveContent.isDownloadable = isDownloadable;
    saveContent.isFeatured = isFeatured;
    saveContent.isPaid = isRegistrationFeePaid;
    saveContent.isReadyForApproval = isReadyForApprovalValue;
    saveContent.registrationFeePaid = registrationFeePaidValue;
    saveContent.registrationFeeDetails = registrationFeeDetailsValue;
    saveContent.genreList = selectedGeners;
    saveContent.languageList = selectedLanguages
        .map((item) => LanguageList(language: item.language, fileUrl: ''))
        .toList();
    saveContent.mediaHouseId = mediaHouse.id!;
    saveContent.price = double.tryParse(priceController.text) ?? 0.0;
    saveContent.posterUrlList = [
      poster1Controller.text,
      poster2Controller.text,
      poster3Controller.text,
    ];
    saveContent.ratings = 0;
    saveContent.ratingCount = 0;
    saveContent.releaseDate = releaseDateController.text;
    saveContent.rentlDuration = rentalDurationController.text.isNotEmpty
        ? rentalDurationController.text
        : rentlDurationController.text;
    saveContent.runtime = 0;
    saveContent.numberOfAttempt =
        int.tryParse(numberOfAttemptController.text.trim()) ?? 0;
    saveContent.fullAttempt =
        int.tryParse(fullAttemptController.text.trim()) ?? 0;
    saveContent.subtitleLanguageList = [];
    saveContent.sensorCertificate = censorCertificateController.text;
    saveContent.title = titleController.text;
    saveContent.teaserUrl = teaserUrlController.text;
    saveContent.trailerUrl = trailerUrlController.text;

    ApiHelper apiHelper = ApiHelper();
    try {
      final payload = saveContent.toJson();
      debugPrint("Payload: ${json.encode(payload)}");
      debugPrint("Payload: ${saveContent.toJson()}");
      var response = await apiHelper.postApiWithBody(apiUrl, payload);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final addVideoResponse = AddVideoResponse.fromJson(responseBody);
        if (addVideoResponse.isSuccess == true) {
          Content contentObj = addVideoResponse.data!;
          CustomToast.show(
              context,
              UserMessage.resolve(
                  apiMessage: addVideoResponse.message,
                  fallbackMessage: 'Series added successfully.'),
              isSuccess: true);
          fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
          notifyListeners();
          return contentObj;
        } else {
          debugPrint(
              "Error: ${addVideoResponse.message ?? 'Record not added'}");
          CustomToast.show(
              context,
              UserMessage.resolve(
                  apiMessage: addVideoResponse.message,
                  fallbackMessage:
                      'Unable to add the series. Please try again.'),
              isSuccess: false);
          return null;
        }
      } else {
        debugPrint("Failed: ${response.statusCode}, ${response.body}");
        CustomToast.show(
            context,
            UserMessage.forStatus(response.statusCode,
                fallbackMessage: 'Unable to add the series. Please try again.'),
            isSuccess: false);
      }
    } catch (error) {
      debugPrint("Error: $error");
      CustomToast.show(
          context,
          UserMessage.forException(error,
              fallbackMessage: 'Unable to add the series. Please try again.'),
          isSuccess: false);
    }
    return null;
  }

  Future<Content?> editContent(BuildContext context, int movieId) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    if (mediaHouse == null) {
      CustomToast.show(
          context, "Production House not found. Please login again.",
          isSuccess: false);
      return null;
    }

    Availability availability = Availability();
    DateTime now = DateTime.now();
    String isoDate = now.toUtc().toIso8601String();
    String apiUrl = ApiConstant.editVideoById(movieId);

    SaveContentRequest saveContent = SaveContentRequest();
    try {
      final existingContent = _content;
      saveContent.id = movieId;
      saveContent.ageRating = ageRatingController.text;
      saveContent.aggrementDocument = agreementDocumentUrl;
      saveContent.approvalStatus = derivedApprovalStatus;
      saveContent.approvedDateTime = null;
      saveContent.audioFormatList = selectedAudioFormat;
      saveContent.availability = availability;
      saveContent.castList = castList;
      saveContent.contentUrl = movieUrlController.text;
      saveContent.directorList = directorList;
      saveContent.description = descriptionController.text;
      saveContent.genersList = selectedGeners;
      saveContent.isAggrement = hasUploadedAgreement;
      saveContent.isDownloadable = isDownloadable;
      saveContent.isFeatured = isFeatured;
      saveContent.isPaid = isRegistrationFeePaid;
      saveContent.isReadyForApproval = isReadyForApprovalValue;
      saveContent.registrationFeePaid = registrationFeePaidValue;
      saveContent.registrationFeeDetails = registrationFeeDetailsValue;
      saveContent.languageList = selectedLanguages;
      saveContent.mediaHouseId = existingContent?.mediaHouseId ?? mediaHouse.id;
      saveContent.price = double.tryParse(priceController.text) ?? 0.0;
      saveContent.posterUrlList = [
        poster1Controller.text,
        poster2Controller.text,
        poster3Controller.text,
      ];
      saveContent.ratings = existingContent?.ratings ?? 0;
      saveContent.ratingCount = existingContent?.ratingCount ?? 0;
      saveContent.reason = existingContent?.reason ?? '';
      saveContent.releaseDate = releaseDateController.text;
      saveContent.releaseTime = '';
      saveContent.rentlDuration = rentalDurationController.text.isNotEmpty
          ? rentalDurationController.text
          : rentlDurationController.text;
      saveContent.totalRevenue = existingContent?.totalRevenue ?? 0;
      saveContent.runtime = double.tryParse(runTimeController.text) ?? 0.0;
      saveContent.numberOfAttempt =
          int.tryParse(numberOfAttemptController.text.trim()) ?? 0;
      saveContent.fullAttempt =
          int.tryParse(fullAttemptController.text.trim()) ?? 0;
      saveContent.subtitleLanguageList = selectedSubLanguages;
      saveContent.sensorCertificate = censorCertificateController.text;
      saveContent.type = typeController.text;
      saveContent.title = titleController.text;
      if (teaserUrlController.text.trim().isEmpty) {
        for (final langMap in _movieVariantControllers.values) {
          if (langMap['teaser']?.text.trim().isNotEmpty == true) {
            teaserUrlController.text = langMap['teaser']!.text.trim();
            break;
          }
        }
      }
      if (trailerUrlController.text.trim().isEmpty) {
        for (final langMap in _movieVariantControllers.values) {
          if (langMap['trailer']?.text.trim().isNotEmpty == true) {
            trailerUrlController.text = langMap['trailer']!.text.trim();
            break;
          }
        }
      }
      saveContent.teaserUrl = teaserUrlController.text;
      saveContent.trailerUrl = trailerUrlController.text;
      saveContent.uploadDateTime = isoDate;
      saveContent.views = existingContent?.views ?? 0;

      ApiHelper apiHelper = ApiHelper();
      final payload = saveContent.toJson();
      debugPrint("Payload: ${json.encode(payload)}");
      var response = await apiHelper.putApiWithBody(apiUrl, payload);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final addVideoResponse = AddVideoResponse.fromJson(responseBody);
        if (addVideoResponse.isSuccess == true) {
          CustomToast.show(
              context,
              UserMessage.resolve(
                  apiMessage: addVideoResponse.message,
                  fallbackMessage: 'Content updated successfully.'),
              isSuccess: true);
          fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
          notifyListeners();
          return addVideoResponse.data;
        } else {
          debugPrint(
              "Edit failed: ${addVideoResponse.message ?? 'Unknown error'}");
          CustomToast.show(context, addVideoResponse.message ?? "Edit failed.",
              isSuccess: false);
        }
      } else {
        debugPrint("Failed: ${response.statusCode}, ${response.body}");
        CustomToast.show(
            context,
            UserMessage.forStatus(response.statusCode,
                fallbackMessage:
                    'Unable to update the content. Please try again.'),
            isSuccess: false);
      }
    } catch (error) {
      debugPrint("Error: $error");
      CustomToast.show(
          context, "An unexpected error occurred. Please try again.",
          isSuccess: false);
    }
    return null;
  }

  bool get hasCastDraft =>
      castNameController.text.trim().isNotEmpty ||
      castDescriptionController.text.trim().isNotEmpty ||
      castImageController.text.trim().isNotEmpty;

  bool get hasIncompleteCastDraft =>
      hasCastDraft && castNameController.text.trim().isEmpty;

  bool get hasAnyCastToSave => _pendingCasts.isNotEmpty || hasCastDraft;
  bool get hasAnyCrewToSave => _pendingCrews.isNotEmpty || hasCrewDraft;

  Map<String, String> _buildCastFromControllers() {
    return {
      "name": castNameController.text.trim(),
      "role": "Actor",
      "description": castDescriptionController.text.trim(),
      "image": castImageController.text.trim(),
    };
  }

  bool addCurrentCastToQueue(context) {
    final cast = _buildCastFromControllers();
    if ((cast["name"] ?? "").isEmpty) {
      CustomToast.show(
        context,
        "Please enter the cast name.",
        isSuccess: false,
      );
      return false;
    }

    _pendingCasts.add(cast);
    clearCastDraft(notify: false);
    notifyListeners();
    CustomToast.show(context, "Cast added to queue", isSuccess: true);
    return true;
  }

  void removePendingCastAt(int index) {
    if (index < 0 || index >= _pendingCasts.length) return;
    _pendingCasts.removeAt(index);
    notifyListeners();
  }

  void clearCastDraft({bool notify = true}) {
    castNameController.clear();
    castRoleController.clear();
    castDescriptionController.clear();
    castImageController.clear();
    castImageUploadProgress = 0.0;
    _isCastImageUploading = false;
    if (notify) notifyListeners();
  }

  bool get hasCrewDraft =>
      crewNameController.text.trim().isNotEmpty ||
      crewRoleController.text.trim().isNotEmpty ||
      crewImageController.text.trim().isNotEmpty;

  Map<String, String> _buildCrewFromControllers() {
    return {
      "name": crewNameController.text.trim(),
      "role": crewRoleController.text.trim(),
      "image": crewImageController.text.trim(),
    };
  }

  bool addCurrentCrewToQueue(context) {
    final crew = _buildCrewFromControllers();
    if ((crew["name"] ?? "").isEmpty || (crew["role"] ?? "").isEmpty) {
      CustomToast.show(
        context,
        "Please enter the crew name and role.",
        isSuccess: false,
      );
      return false;
    }
    _pendingCrews.add(crew);
    clearCrewDraft(notify: false);
    notifyListeners();
    CustomToast.show(context, "Crew added to queue", isSuccess: true);
    return true;
  }

  void removePendingCrewAt(int index) {
    if (index < 0 || index >= _pendingCrews.length) return;
    _pendingCrews.removeAt(index);
    notifyListeners();
  }

  void clearCrewDraft({bool notify = true}) {
    crewNameController.clear();
    crewRoleController.clear();
    crewImageController.clear();
    crewImageUploadProgress = 0.0;
    _isCrewImageUploading = false;
    if (notify) notifyListeners();
  }

  Future<bool> _saveSingleCastPayload(
    context, {
    required int contentId,
    required int seasonId,
    required Map<String, String> cast,
  }) async {
    final payload = {
      "castId": 0,
      "contentId": contentId,
      "description": (cast["description"] ?? "").trim(),
      "image": (cast["image"] ?? "").trim(),
      "name": (cast["name"] ?? "").trim(),
      "role": (cast["role"] ?? "").trim(),
      "seasonId": seasonId,
    };

    final apiHelper = ApiHelper();
    try {
      final response =
          await apiHelper.postApiWithBody(ApiConstant.saveCast, payload);
      if (response.statusCode != 200) {
        CustomToast.show(context, "Failed to save cast. Please try again.",
            isSuccess: false);
        return false;
      }

      final responseBody = json.decode(response.body);
      final bool success =
          responseBody["success"] == true || responseBody["isSuccess"] == true;
      if (!success) {
        final message =
            (responseBody["message"] ?? "Failed to save cast.").toString();
        CustomToast.show(context, message, isSuccess: false);
        return false;
      }
      return true;
    } catch (error) {
      debugPrint("Error while saving cast: $error");
      CustomToast.show(
          context, "An unexpected error occurred while saving cast.",
          isSuccess: false);
      return false;
    }
  }

  Future<bool> saveCastForContent({
    context,
    required int contentId,
    int seasonId = 0,
  }) async {
    if (contentId <= 0) {
      CustomToast.show(context, "Invalid content ID for cast save.",
          isSuccess: false);
      return false;
    }

    final cast = _buildCastFromControllers();
    if ((cast["name"] ?? "").isEmpty) {
      CustomToast.show(
        context,
        "Please enter the cast name.",
        isSuccess: false,
      );
      return false;
    }

    final saved = await _saveSingleCastPayload(
      context,
      contentId: contentId,
      seasonId: seasonId,
      cast: cast,
    );
    if (saved) {
      clearCastDraft();
      CustomToast.show(context, "Cast saved successfully", isSuccess: true);
    }
    return saved;
  }

  Future<bool> updateCastMember(
    BuildContext context, {
    required int castId,
    required int contentId,
    required String name,
    required String role,
    String description = '',
    String image = '',
    int seasonId = 0,
    int shortId = 0,
  }) async {
    final payload = {
      "castId": castId,
      "contentId": contentId,
      "description": description.trim(),
      "image": image.trim(),
      "name": name.trim(),
      "role": role.trim(),
      "seasonId": seasonId,
      "shortId": shortId,
    };

    final apiHelper = ApiHelper();
    try {
      final response =
          await apiHelper.putApiWithBody(ApiConstant.updateCast, payload);

      if (response.statusCode != 200 && response.statusCode != 201) {
        String msg = "Failed to update cast details (${response.statusCode}).";
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded["message"] != null) {
            msg = decoded["message"].toString();
          }
        } catch (_) {}
        CustomToast.show(context, msg, isSuccess: false);
        return false;
      }

      CustomToast.show(context, "Cast updated successfully", isSuccess: true);
      return true;
    } catch (error) {
      debugPrint("Error updating cast member: $error");
      CustomToast.show(
        context,
        "Network error occurred while updating cast: $error",
        isSuccess: false,
      );
      return false;
    }
  }

  Future<bool> addDirectCastMember(
    BuildContext context, {
    required int contentId,
    required String name,
    required String role,
    String description = '',
    String image = '',
    int seasonId = 0,
  }) async {
    final payload = {
      "castId": 0,
      "contentId": contentId,
      "description": description.trim(),
      "image": image.trim(),
      "name": name.trim(),
      "role": role.trim(),
      "seasonId": seasonId,
    };

    final apiHelper = ApiHelper();
    try {
      final response =
          await apiHelper.postApiWithBody(ApiConstant.saveCast, payload);

      if (response.statusCode != 200 && response.statusCode != 201) {
        String msg = "Failed to save cast details (${response.statusCode}).";
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map && decoded["message"] != null) {
            msg = decoded["message"].toString();
          }
        } catch (_) {}
        CustomToast.show(context, msg, isSuccess: false);
        return false;
      }

      CustomToast.show(context, "Cast added successfully", isSuccess: true);
      return true;
    } catch (error) {
      debugPrint("Error adding cast member: $error");
      CustomToast.show(
        context,
        "Network error occurred while adding cast: $error",
        isSuccess: false,
      );
      return false;
    }
  }

  Future<String?> uploadSingleImageFile(PlatformFile file) async {
    final url = Uri.parse(ApiConstant.uploadContentImg);
    try {
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(await AuthService.authHeaders());

      if (kIsWeb) {
        if (file.bytes == null) return null;
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
        ));
      } else {
        if (file.path == null) return null;
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
        ));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final res = ContentImageUploadResponse.fromJson(jsonDecode(body));
        return res.data?.fileUrl;
      }
    } catch (e) {
      debugPrint('Image upload error: $e');
    }
    return null;
  }

  Future<bool> saveAllCastsForContent(
    context, {
    required int contentId,
    int seasonId = 0,
  }) async {
    if (contentId <= 0) {
      CustomToast.show(context, "Invalid content ID for cast save.",
          isSuccess: false);
      return false;
    }

    if (hasIncompleteCastDraft) {
      CustomToast.show(
        context,
        "Please complete current cast details before submit.",
        isSuccess: false,
      );
      return false;
    }

    final castsToSave = List<Map<String, String>>.from(_pendingCasts);
    if (hasCastDraft) {
      castsToSave.add(_buildCastFromControllers());
    }

    if (castsToSave.isEmpty) return true;

    for (final cast in castsToSave) {
      final saved = await _saveSingleCastPayload(
        context,
        contentId: contentId,
        seasonId: seasonId,
        cast: cast,
      );
      if (!saved) return false;
    }

    _pendingCasts.clear();
    clearCastDraft(notify: false);
    notifyListeners();
    CustomToast.show(
      context,
      "${castsToSave.length} cast${castsToSave.length > 1 ? "s" : ""} saved successfully",
      isSuccess: true,
    );
    return true;
  }

  Future<bool> saveAllCrewsForContent(
    context, {
    required int contentId,
    int seasonId = 0,
  }) async {
    if (contentId <= 0) {
      CustomToast.show(context, "Invalid content ID for crew save.",
          isSuccess: false);
      return false;
    }

    final crewsToSave = List<Map<String, String>>.from(_pendingCrews);
    if (hasCrewDraft) {
      final crewDraft = _buildCrewFromControllers();
      if ((crewDraft["name"] ?? "").isEmpty ||
          (crewDraft["role"] ?? "").isEmpty) {
        CustomToast.show(
          context,
          "Please complete the crew name and role before submitting.",
          isSuccess: false,
        );
        return false;
      }
      crewsToSave.add(crewDraft);
    }

    if (crewsToSave.isEmpty) return true;

    for (final crew in crewsToSave) {
      if ((crew["name"] ?? "").isEmpty || (crew["role"] ?? "").isEmpty) {
        CustomToast.show(
          context,
          "Each crew member must have a name and role.",
          isSuccess: false,
        );
        return false;
      }

      final payload = {
        "name": (crew["name"] ?? "").trim(),
        "role": (crew["role"] ?? "").trim(),
        "image": (crew["image"] ?? "").trim(),
        "description": "",
      };

      final saved = await _saveSingleCastPayload(
        context,
        contentId: contentId,
        seasonId: seasonId,
        cast: payload,
      );
      if (!saved) return false;
    }

    _pendingCrews.clear();
    clearCrewDraft(notify: false);
    notifyListeners();
    CustomToast.show(
      context,
      "${crewsToSave.length} crew${crewsToSave.length > 1 ? "s" : ""} saved successfully",
      isSuccess: true,
    );
    return true;
  }

  File? selectedImage;

  void setImage(XFile pickedFile) {
    selectedImage = File(pickedFile.path);
    notifyListeners();
  }

  List<User> users = [];
  List<User> get userList => users;

  Future<void> fetchUsers() async {
    String apiUrl = ApiConstant.getAllUser;
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetAllUserResponse getAllUserResponse =
            GetAllUserResponse.fromJson(responseBody);
        if (getAllUserResponse.success == true) {
          if (getAllUserResponse.data != null) {
            users = getAllUserResponse.data!.user!;
            print("User list:::::::" + users.length.toString());
            notifyListeners();
          } else {
            debugPrint("empty list: ${getAllUserResponse.message}");
          }
        } else {
          debugPrint("Error: ${getAllUserResponse.message}");
        }
      } else {
        throw Exception(
            'Failed to fetch users. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching users.');
    }
  }

  io.File? _imageFile;
  html.File? _webFile;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  io.File? get imageFile => _imageFile;
  html.File? get webFile => _webFile;
  String? get uploadedImageUrl => _uploadedImageUrl;
  bool get isUploading => _isUploading;

  Future<void> pickImage(String label, context) async {
    final shouldValidate = label != "Cast Image" && label != "Crew Image";
    if (kIsWeb) {
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement();
      uploadInput.accept = 'image/*';
      uploadInput.click();
      uploadInput.onChange.listen((event) async {
        if (uploadInput.files != null && uploadInput.files!.isNotEmpty) {
          final file = uploadInput.files!.first;
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoad.first;
          final bytes = Uint8List.fromList((reader.result as List).cast<int>());
          if (shouldValidate) {
            final validation = await ImageValidationService.validateBytes(
              bytes: bytes,
              fileName: file.name,
              sizeInBytes: file.size,
              type: _imageValidationTypeForLabel(label),
            );
            if (!validation.isValid) {
              CustomToast.show(context, validation.message ?? 'Invalid image.',
                  isSuccess: false);
              return;
            }
          }
          _webFile = file;
          await uploadImage(label);
          notifyListeners();
        }
      });
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final file = io.File(pickedFile.path);
        final bytes = await file.readAsBytes();
        if (shouldValidate) {
          final validation = await ImageValidationService.validateBytes(
            bytes: bytes,
            fileName: pickedFile.name,
            sizeInBytes: bytes.lengthInBytes,
            type: _imageValidationTypeForLabel(label),
          );
          if (!validation.isValid) {
            CustomToast.show(context, validation.message ?? 'Invalid image.',
                isSuccess: false);
            return;
          }
        }
        _imageFile = file;
        await uploadImage(label);
        notifyListeners();
      }
    }
  }

  Future<void> uploadImage(String label) async {
    if ((!kIsWeb && _imageFile == null) || (kIsWeb && _webFile == null)) {
      return;
    }

    final url = Uri.parse(ApiConstant.uploadContentImg);

    _setUploadingStatus(label, true);
    _setProgressByLabel(label, 0.0);
    _isUploading = true;
    notifyListeners();

    try {
      if (kIsWeb && _webFile != null) {
        final request = http.MultipartRequest('POST', url);
        final reader = html.FileReader();
        reader.readAsArrayBuffer(_webFile!);
        await reader.onLoad.first;
        final byteData = reader.result as List<int>;

        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          byteData,
          filename: _webFile!.name,
        );
        request.files.add(multipartFile);

        Timer.periodic(Duration(milliseconds: 100), (timer) {
          if (_getProgressByLabel(label) < 0.9) {
            _setProgressByLabel(label, _getProgressByLabel(label) + 0.1);
            notifyListeners();
          } else {
            timer.cancel();
          }
        });

        final response = await request.send();
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          ContentImageUploadResponse contentImageUploadResponse =
              ContentImageUploadResponse.fromJson(jsonDecode(responseBody));
          _uploadedImageUrl = contentImageUploadResponse.data!.fileUrl;
          _setControllerText(label, _uploadedImageUrl!);
          _setProgressByLabel(label, 1.0);
        } else {
          print("Image upload failed with status: ${response.statusCode}");
          _setProgressByLabel(label, 0.0);
        }
      } else if (!kIsWeb && _imageFile != null) {
        final totalBytes = await _imageFile!.length();
        int bytesSent = 0;

        final stream = http.ByteStream(_imageFile!.openRead().transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              bytesSent += data.length;
              final progress = bytesSent / totalBytes;
              _setProgressByLabel(label, progress);
              notifyListeners();
              sink.add(data);
            },
          ),
        ));

        final request = http.MultipartRequest('POST', url);
        request.files.add(http.MultipartFile(
          'file',
          stream,
          totalBytes,
          filename: _imageFile!.path.split('/').last,
        ));

        final response = await request.send();
        if (response.statusCode == 200) {
          final responseBody = await response.stream.bytesToString();
          _uploadedImageUrl = jsonDecode(responseBody);
          _setControllerText(label, _uploadedImageUrl!);
          _setProgressByLabel(label, 1.0);
          print("$label uploaded successfully: $_uploadedImageUrl");
        } else {
          print("Image upload failed with status: ${response.statusCode}");
          _setProgressByLabel(label, 0.0);
        }
      }
    } catch (e) {
      print('Error uploading image: $e');
      _setProgressByLabel(label, 0.0);
    } finally {
      _setUploadingStatus(label, false);
      _isUploading = false;
      notifyListeners();
    }
  }

  void _setControllerText(String label, String url) {
    switch (label) {
      case "Trailer File":
        trailerUrlController.text = url;
        break;
      case "Teaser File":
        teaserUrlController.text = url;
        break;
      case "Movie File":
        movieUrlController.text = url;
        break;
      case "Censor Certificate":
        censorCertificateController.text = url;
        break;
      case "Poster 1":
        poster1Controller.text = url;
        break;
      case "Poster 2":
        poster2Controller.text = url;
        break;
      case "Poster 3":
        poster3Controller.text = url;
        break;
      case "Cast Image":
        castImageController.text = url;
        break;
      case "Crew Image":
        crewImageController.text = url;
        break;
    }
  }

  double _getProgressByLabel(String label) {
    switch (label) {
      case "Trailer File":
        return trailerUploadProgress;
      case "Teaser File":
        return teaserUploadProgress;
      case "Movie File":
        return movieUploadProgress;
      case "Censor Certificate":
        return censorUploadProgress;
      case "Poster 1":
        return poster1UploadProgress;
      case "Poster 2":
        return poster2UploadProgress;
      case "Poster 3":
        return poster3UploadProgress;
      case "Cast Image":
        return castImageUploadProgress;
      case "Crew Image":
        return crewImageUploadProgress;
      default:
        return 0.0;
    }
  }

  deleteVideo(int id, context) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    String apiUrl = ApiConstant.deleteVideoById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.deleteApi(apiUrl);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        CustomToast.show(
            context,
            UserMessage.resolve(
                apiResponse: decoded,
                fallbackMessage: 'Content deleted successfully.'),
            isSuccess: true);
        fetchMoviesByStatusAndMediaHouseId("PENDING", mediaHouse!.id!);
        notifyListeners();
        Navigator.pop(context);
      } else {
        throw Exception(
            'Failed to fetch mediaHouse. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching mediaHouse.');
    }
  }

  Future<Content?> getContentById(int id) async {
    String apiUrl = ApiConstant.getVideoById(id);
    ApiHelper apiHelper = ApiHelper();
    try {
      var response = await apiHelper.getApi(apiUrl);
      if (response.statusCode == 200) {
        Map<String, dynamic> responseBody = json.decode(response.body);
        GetContentResponse addUserResponse =
            GetContentResponse.fromJson(responseBody);
        print("\ncontent by id response " + responseBody.toString());
        if (addUserResponse.success == true) {
          if (addUserResponse.data != null &&
              addUserResponse.data!.contentList != null) {
            _content = addUserResponse.data!.contentList!;
            notifyListeners();
            return _content;
          } else {
            debugPrint("empty data: ${addUserResponse.message}");
          }
        } else {
          debugPrint("Error: ${addUserResponse.message}");
        }
      } else {
        throw Exception(
            'Failed to delete user. Status code: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint("Error: $error");
      throw Exception('An error occurred while delete user.');
    }
    return null;
  }

  Future<void> fetchCastByContentId(int contentId) async {
    if (contentId <= 0) {
      _contentCastList = [];
      notifyListeners();
      return;
    }

    final apiUrl = ApiConstant.getCastByContentId(contentId);
    final apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode != 200) {
        _contentCastList = [];
        notifyListeners();
        return;
      }

      final responseBody = json.decode(response.body);
      final dynamic castData = responseBody["data"]?["cast"];
      if (castData is List) {
        _contentCastList = castData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _pendingCasts.clear();
        _pendingCrews.clear();
        for (final item in _contentCastList) {
          final isCrew = item["isCrew"] == true ||
              item["isCrew"] == "true" ||
              item["crew"] == true;
          final map = <String, String>{
            "name": (item["name"] ?? item["castName"] ?? "").toString(),
            "role": (item["role"] ?? item["castRole"] ?? "").toString(),
            "image":
                (item["image"] ?? item["imageUrl"] ?? item["castImage"] ?? "")
                    .toString(),
            "description": (item["description"] ?? "").toString(),
          };
          if (isCrew) {
            _pendingCrews.add(map);
          } else {
            _pendingCasts.add(map);
          }
        }
      } else {
        _contentCastList = [];
      }
      notifyListeners();
    } catch (error) {
      debugPrint("Error fetching cast by content id: $error");
      _contentCastList = [];
      notifyListeners();
    }
  }

  void setValu(Content movie) {
    _content = movie;
    _activeContentId = movie.id?.toString();
    releaseDateController.text = movie.releaseDate ?? "";
    ageRatingController.text = movie.ageRating ?? '';
    castController.text = (movie.castList ?? []).join(', ');
    censorCertificateController.text = movie.sensorCertificate ?? '';
    directorController.text = (movie.directorList ?? []).join(', ');
    descriptionController.text = movie.description ?? '';
    titleController.text = movie.title ?? '';
    typeController.text = (movie.type ?? 'MOVIE').toUpperCase();
    rentlDurationController.text = movie.rentlDuration ?? "";
    rentalDurationController.text = movie.rentlDuration ?? "";
    priceController.text = movie.price?.toString() ?? "";
    runTimeController.text = movie.runtime?.toString() ?? "";
    numberOfAttemptController.text = (movie.numberOfAttempt ?? 0).toString();
    fullAttemptController.text = (movie.fullAttempt ?? 0).toString();
    _selectedLanguages = movie.languageList ?? [];
    _syncAudioLanguagesWithSelectedLanguages();
    _selectedSubLanguages = movie.subtitleLanguageList ?? [];
    _selectedAudioFormat = movie.audioFormatList ?? [];
    _selectedGeners = movie.genreList ?? [];
    _isDownloadable = movie.isDownloadable ?? false;
    _isFeatured = movie.isFeatured ?? false;
    _agreementFileName = null;
    agreementDocumentUrlController.text = movie.aggrementDocument ?? '';
    if ((movie.aggrementDocument ?? '').trim().isNotEmpty) {
      final uri = Uri.tryParse(movie.aggrementDocument!.trim());
      final segments = uri?.pathSegments ?? const <String>[];
      _agreementFileName = segments.isEmpty
          ? 'Agreement uploaded'
          : Uri.decodeComponent(segments.last);
    }
    _isAgreementUploading = false;
    _agreementUploadProgress = 0.0;
    _isRegistrationFeePaid = movie.isPaid == true ||
        (movie.registrationFeePaid ?? '').toUpperCase() == 'Y';
    if ((movie.aggrementDocument ?? '').trim().isNotEmpty) {
      agreementDocumentUrlController.text = movie.aggrementDocument!.trim();
    }
    registrationFeeDetailsController.text = movie.registrationFeeDetails ?? '';
    if (agreementDocumentUrlController.text.trim().isEmpty &&
        (movie.aggrementDocument ?? '').trim().isNotEmpty) {
      agreementDocumentUrlController.text = movie.aggrementDocument!.trim();
    }
    if (agreementDocumentUrlController.text.trim().isNotEmpty) {
      final uri = Uri.tryParse(agreementDocumentUrlController.text.trim());
      final segments = uri?.pathSegments ?? const <String>[];
      _agreementFileName = segments.isEmpty
          ? 'Agreement uploaded'
          : Uri.decodeComponent(segments.last);
    }
    poster1Controller.clear();
    poster2Controller.clear();
    poster3Controller.clear();
    final posters = (movie.posterUrlList ?? [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    poster1Controller.text = posters.isNotEmpty ? posters[0] : '';
    poster2Controller.text = posters.length > 1 ? posters[1] : '';
    poster3Controller.text = posters.length > 2 ? posters[2] : '';
    teaserUrlController.text = movie.teaserUrl ?? '';
    trailerUrlController.text = movie.trailerUrl ?? '';
    movieUrlController.text = movie.contentUrl ?? '';
    censorCertificateController.text = movie.sensorCertificate ?? '';
    teaserUploadProgress = teaserUrlController.text.trim().isEmpty ? 0.0 : 1.0;
    trailerUploadProgress =
        trailerUrlController.text.trim().isEmpty ? 0.0 : 1.0;
    movieUploadProgress = movieUrlController.text.trim().isEmpty ? 0.0 : 1.0;
    censorUploadProgress =
        censorCertificateController.text.trim().isEmpty ? 0.0 : 1.0;
    poster1UploadProgress = poster1Controller.text.trim().isEmpty ? 0.0 : 1.0;
    poster2UploadProgress = poster2Controller.text.trim().isEmpty ? 0.0 : 1.0;
    poster3UploadProgress = poster3Controller.text.trim().isEmpty ? 0.0 : 1.0;

    _pendingCasts.clear();
    _pendingCrews.clear();
    if (movie.castList != null) {
      for (final castName in movie.castList!) {
        if (castName.trim().isNotEmpty) {
          _pendingCasts.add({
            'name': castName.trim(),
            'role': '',
            'image': '',
            'description': '',
          });
        }
      }
    }
    if (movie.directorList != null) {
      for (final directorName in movie.directorList!) {
        if (directorName.trim().isNotEmpty) {
          _pendingCrews.add({
            'name': directorName.trim(),
            'role': 'Director',
            'image': '',
            'description': '',
          });
        }
      }
    }

    for (final lang in _selectedLanguages) {
      final name = (lang.language ?? '').trim();
      if (name.isNotEmpty) {
        movieVariantController(name, 'poster1');
        final map = _movieVariantControllers[name];
        if (map != null) {
          map['poster1']!.text = poster1Controller.text;
          map['poster2']!.text = poster2Controller.text;
          map['poster3']!.text = poster3Controller.text;
          map['teaser']!.text = teaserUrlController.text;
          map['trailer']!.text = trailerUrlController.text;
          map['movie']!.text = movieUrlController.text;
          map['subtitle']!.text = _selectedSubLanguages.join(', ');
        }
      }
    }

    notifyListeners();
  }

  setMoviePercentage(BuildContext context, Content content, int adminPercentage,
      int mediaHousePercentage) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    DateTime now = DateTime.now();
    String isoDate = now.toUtc().toIso8601String();
    String apiUrl = ApiConstant.setPercentage;
    print(apiUrl);
    PercentageRequest percentageRequest = PercentageRequest();
    percentageRequest.contentList = content.id;
    percentageRequest.date = isoDate;
    percentageRequest.isActive = true;
    percentageRequest.mediaHouse = mediaHouse!.id!;
    percentageRequest.percentageAdmin = adminPercentage;
    percentageRequest.percentageMediaHouse = mediaHousePercentage;
    percentageRequest.ticketRate = content.price;
    ApiHelper apiHelper = ApiHelper();
    try {
      final payload = percentageRequest.toJson();
      debugPrint("Payload: ${json.encode(payload)}");
      var response = await apiHelper.postApiWithBody(
        apiUrl,
        payload,
      );
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final addVideoResponse = AddVideoResponse.fromJson(responseBody);
        if (addVideoResponse.isSuccess == true) {
          CustomToast.show(
              context,
              UserMessage.resolve(
                  apiMessage: addVideoResponse.message,
                  fallbackMessage: 'Percentage updated successfully.'),
              isSuccess: true);
          fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
          notifyListeners();
          Navigator.of(context).pop();
        } else {
          debugPrint("Empty data: Record not added");
        }
      } else {
        debugPrint("Failed: ${response.statusCode}, ${response.body}");
      }
    } catch (error) {
      debugPrint("Error: $error");
    }
  }

  String? teaserFileName;
  String? trailerFileName;
  String? movieFileName;

  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateNameController = TextEditingController();
  bool isYear = false;
  bool isMonth = true;
  bool isWeek = false;
  List<GraphData> chartData = [];
  bool _isLoadingRatingReviews = false;
  List<RatingReviewItem> _ratingReviews = [];
  double _ratingAvg = 0;

  bool get isLoadingRatingReviews => _isLoadingRatingReviews;
  List<RatingReviewItem> get ratingReviews => _ratingReviews;
  double get ratingAvg => _ratingAvg;

  falseAllFilter() {
    isYear = false;
    isMonth = false;
    isWeek = false;
  }

  Future<void> contentRevenueGraph(
    int selectedTimeRange,
    int id,
    String startDateString,
    String endDateString, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) async {
    if (selectedTimeRange == 0) {
      isWeek = true;
      isMonth = false;
      isYear = false;
    } else if (selectedTimeRange == 1) {
      isWeek = false;
      isMonth = true;
      isYear = false;
    } else if (selectedTimeRange == 2) {
      isWeek = false;
      isMonth = false;
      isYear = true;
    } else {
      isWeek = false;
      isMonth = false;
      isYear = false;
    }
    final apiUrl = ApiConstant.contentRevenueGraph(
      id,
      startDateString,
      endDateString,
      isYear,
      isMonth,
      isWeek,
      contentType: contentType,
      country: country,
      state: state,
      district: district,
      taluka: taluka,
      city: city,
    );
    final data = await _fetchContentGraphData(context, apiUrl);
    chartData = data;
    notifyListeners();
  }

  Future<bool> pickAndUploadAgreementDocument() async {
    _isAgreementUploading = true;
    _agreementUploadProgress = 0.0;
    notifyListeners();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        _isAgreementUploading = false;
        notifyListeners();
        return false;
      }

      final pickedFile = result.files.single;
      final request =
          http.MultipartRequest('POST', Uri.parse(ApiConstant.uploadImg));

      if (kIsWeb) {
        final bytes = pickedFile.bytes;
        if (bytes == null) {
          _agreementUploadProgress = 0.0;
          _isAgreementUploading = false;
          notifyListeners();
          return false;
        }
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );
      } else {
        final path = pickedFile.path;
        if (path == null || path.isEmpty) {
          _agreementUploadProgress = 0.0;
          _isAgreementUploading = false;
          notifyListeners();
          return false;
        }
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      _agreementUploadProgress = 0.45;
      notifyListeners();

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode != 200) {
        _agreementUploadProgress = 0.0;
        _isAgreementUploading = false;
        notifyListeners();
        return false;
      }

      final parsed = ImageUploadResponse.fromJson(
        jsonDecode(responseBody) as Map<String, dynamic>,
      );
      agreementDocumentUrlController.text = parsed.data?.fileUrl ?? '';
      agreementSignedDateController.text =
          DateTime.now().toIso8601String().split('T').first;
      _agreementFileName = pickedFile.name;
      registrationFeeDetailsController.text = registrationFeeDetailsValue;
      _agreementUploadProgress = 1.0;
      _isAgreementUploading = false;
      notifyListeners();
      return agreementDocumentUrlController.text.trim().isNotEmpty;
    } catch (error) {
      debugPrint('Agreement upload failed: $error');
      _agreementUploadProgress = 0.0;
      _isAgreementUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> updateContentAgreementWorkflow({
    required int contentId,
  }) async {
    if (contentId <= 0) {
      return {
        'success': false,
        'message': 'Content details are not available.',
      };
    }

    registrationFeeDetailsController.text = registrationFeeDetailsValue;
    final payload = <String, dynamic>{
      'aggrementDocument': agreementDocumentUrl,
      'id': contentId,
      'isAggrement': hasUploadedAgreement,
      'isPaid': isRegistrationFeePaid,
      'isReadyForApproval': isReadyForApprovalValue,
      'registrationFeeDetails': registrationFeeDetailsValue,
      'registrationFeePaid': registrationFeePaidValue,
    };

    try {
      final response = await ApiHelper().putApiWithBody(
        ApiConstant.editVideoById(contentId),
        payload,
      );
      final Object? decoded =
          response.body.trim().isEmpty ? null : jsonDecode(response.body);
      final responseMap = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final successValue = responseMap['success'] ??
          responseMap['isSuccess'] ??
          responseMap['status'];
      final backendSuccess = successValue == true ||
          successValue == 1 ||
          successValue?.toString().toLowerCase() == 'true' ||
          successValue?.toString().toLowerCase() == 'success';
      final httpSuccess =
          response.statusCode >= 200 && response.statusCode < 300;
      final succeeded = httpSuccess && (successValue == null || backendSuccess);
      final message = UserMessage.resolve(
        apiResponse: responseMap,
        statusCode: response.statusCode,
        fallbackMessage: succeeded
            ? 'Content workflow updated successfully.'
            : 'Unable to update the content workflow. Please try again.',
      );

      if (succeeded && _content != null && _content!.id == contentId) {
        _content!
          ..aggrementDocument = agreementDocumentUrl
          ..isAggrement = hasUploadedAgreement
          ..isPaid = isRegistrationFeePaid
          ..registrationFeeDetails = registrationFeeDetailsValue
          ..registrationFeePaid = registrationFeePaidValue;
        if (isReadyForApprovalValue == "Y") {
          _content!.approvalStatus = "PENDING";
        }
        notifyListeners();
      }

      return {'success': succeeded, 'message': message};
    } catch (error) {
      debugPrint('Content workflow update failed: $error');
      return {
        'success': false,
        'message': UserMessage.forException(
          error,
          fallbackMessage:
              'Unable to update the content workflow. Please try again.',
        ),
      };
    }
  }

  Future<List<GraphData>> fetchContentMetricGraphData(
    int selectedTimeRange,
    int id,
    String startDateString,
    String endDateString, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
  }) async {
    if (selectedTimeRange == 0) {
      isWeek = true;
      isMonth = false;
      isYear = false;
    } else if (selectedTimeRange == 1) {
      isWeek = false;
      isMonth = true;
      isYear = false;
    } else if (selectedTimeRange == 2) {
      isWeek = false;
      isMonth = false;
      isYear = true;
    } else {
      isWeek = false;
      isMonth = false;
      isYear = false;
    }

    final apiUrl = ApiConstant.contentRevenueGraph(
      id,
      startDateString,
      endDateString,
      isYear,
      isMonth,
      isWeek,
      contentType: contentType,
      country: country,
      state: state,
      district: district,
      taluka: taluka,
      city: city,
    );
    return _fetchContentGraphData(context, apiUrl);
  }

  Future<List<GraphData>> _fetchContentGraphData(context, String apiUrl) async {
    final apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      final Map<String, dynamic> responseBody = json.decode(response.body);
      final chartResponse = GraphResponse.fromJson(responseBody);
      if (chartResponse.success == true) {
        return chartResponse.data ?? <GraphData>[];
      }
      CustomToast.show(context, chartResponse.message.toString(),
          isSuccess: chartResponse.success ?? false);
      return <GraphData>[];
    } catch (error) {
      debugPrint("Error occurred while fetching graph data: $error");
      throw Exception('Failed to fetch graph data. Error: $error');
    }
  }

  Future<void> fetchRatingReviewByContentId(int contentId) async {
    if (contentId <= 0) {
      _ratingReviews = [];
      _ratingAvg = 0;
      notifyListeners();
      return;
    }

    _isLoadingRatingReviews = true;
    notifyListeners();

    final apiUrl = ApiConstant.getRatingReviewByContentId(contentId);
    final apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode != 200) {
        _ratingReviews = [];
        _ratingAvg = 0;
        return;
      }

      final Map<String, dynamic> body = json.decode(response.body);
      final reviewRating = body['data']?['reviewRating'];
      final reviews = reviewRating?['reviews'];
      final avgRaw = reviewRating?['ratingAvg'];

      _ratingAvg = avgRaw is num
          ? avgRaw.toDouble()
          : double.tryParse('${avgRaw ?? 0}') ?? 0;

      if (reviews is List) {
        _ratingReviews = reviews
            .whereType<Map>()
            .map((e) => RatingReviewItem.fromJson(
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
            .toList(growable: false);
      } else {
        _ratingReviews = [];
      }
    } catch (error) {
      debugPrint('Error fetching rating reviews: $error');
      _ratingReviews = [];
      _ratingAvg = 0;
    } finally {
      _isLoadingRatingReviews = false;
      notifyListeners();
    }
  }

  // ==========================================
  // CONTENT REVENUE BREAKDOWN (v1 Analytics)
  // ==========================================
  ContentRevenueBreakdownData? _contentRevenueBreakdown;
  bool _isLoadingContentRevenue = false;

  ContentRevenueBreakdownData? get contentRevenueBreakdown =>
      _contentRevenueBreakdown;
  bool get isLoadingContentRevenue => _isLoadingContentRevenue;

  Future<void> fetchContentRevenueBreakdown(
    int contentId, {
    String? startDate,
    String? endDate,
  }) async {
    if (contentId <= 0) {
      _contentRevenueBreakdown = null;
      notifyListeners();
      return;
    }

    _isLoadingContentRevenue = true;
    notifyListeners();

    try {
      final localSharePreferences = LocalSharePreferences();
      final mediaHouse = await localSharePreferences.getMediaHouse();
      final mediaHouseId = mediaHouse?.id ?? 0;

      final apiUrl = ApiConstant.contentRevenueBreakdown(
        mediaHouseId,
        contentId: contentId,
        startDate: startDate,
        endDate: endDate,
      );

      final apiHelper = ApiHelper();
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = json.decode(response.body);
        final breakdownResponse = ContentRevenueBreakdownResponse.fromJson(body);
        _contentRevenueBreakdown = breakdownResponse.data;
      } else {
        _contentRevenueBreakdown = null;
      }
    } catch (error) {
      debugPrint('Error fetching content revenue breakdown: $error');
      _contentRevenueBreakdown = null;
    } finally {
      _isLoadingContentRevenue = false;
      notifyListeners();
    }
  }

  // ==========================================
  // PURCHASED USERS BY CONTENT ID
  // ==========================================
  List<PurchasedUserItem> _purchasedUsers = [];
  bool _isLoadingPurchasedUsers = false;
  int _purchasedUsersTotalCount = 0;
  int _purchasedUsersTotalPages = 1;
  int _purchasedUsersCurrentPage = 0;

  List<PurchasedUserItem> get purchasedUsers => _purchasedUsers;
  bool get isLoadingPurchasedUsers => _isLoadingPurchasedUsers;
  int get purchasedUsersTotalCount => _purchasedUsersTotalCount;
  int get purchasedUsersTotalPages => _purchasedUsersTotalPages;
  int get purchasedUsersCurrentPage => _purchasedUsersCurrentPage;

  Future<void> fetchPurchasedUsers(
    int contentId, {
    String? startDate,
    String? endDate,
    String? state,
    String? city,
    int page = 0,
    int size = 10,
  }) async {
    if (contentId <= 0) {
      _purchasedUsers = [];
      _purchasedUsersTotalCount = 0;
      notifyListeners();
      return;
    }

    _isLoadingPurchasedUsers = true;
    notifyListeners();

    try {
      final apiUrl = ApiConstant.purchasedUsersByContentId(
        contentId: contentId,
        startDate: startDate,
        endDate: endDate,
        state: state,
        city: city,
        page: page,
        size: size,
      );

      final apiHelper = ApiHelper();
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> body = json.decode(response.body);
        final parsed = PurchasedUsersResponse.fromJson(body);
        if (parsed.data != null) {
          _purchasedUsers = parsed.data!.users;
          _purchasedUsersTotalCount = parsed.data!.totalElements;
          _purchasedUsersTotalPages = parsed.data!.totalPages;
          _purchasedUsersCurrentPage = parsed.data!.currentPage;
        } else {
          _purchasedUsers = [];
          _purchasedUsersTotalCount = 0;
        }
      } else {
        _purchasedUsers = [];
        _purchasedUsersTotalCount = 0;
      }
    } catch (error) {
      debugPrint('Error fetching purchased users: $error');
      _purchasedUsers = [];
      _purchasedUsersTotalCount = 0;
    } finally {
      _isLoadingPurchasedUsers = false;
      notifyListeners();
    }
  }

  // ==========================================
  // AUDIENCE ANALYTICS (Location & Age-wise)
  // ==========================================
  List<AudienceMetricItem> _locationAudience = [];
  List<AudienceMetricItem> _ageAudience = [];
  bool _isLoadingAudienceAnalytics = false;

  List<AudienceMetricItem> get locationAudience => _locationAudience;
  List<AudienceMetricItem> get ageAudience => _ageAudience;
  bool get isLoadingAudienceAnalytics => _isLoadingAudienceAnalytics;

  Future<void> fetchAudienceAnalytics(
    int contentId, {
    String? fromDate,
    String? toDate,
  }) async {
    if (contentId <= 0) {
      _locationAudience = [];
      _ageAudience = [];
      notifyListeners();
      return;
    }

    _isLoadingAudienceAnalytics = true;
    notifyListeners();

    final apiHelper = ApiHelper();
    try {
      // 1. Location-wise views
      final locationUrl = ApiConstant.audienceLocationWise(
        contentId: contentId,
        fromDate: fromDate,
        toDate: toDate,
      );
      final locRes = await apiHelper.getApi(locationUrl);
      if (locRes.statusCode >= 200 && locRes.statusCode < 300) {
        final locBody = json.decode(locRes.body);
        final locParsed = AudienceAnalyticsResponse.fromJson(locBody);
        _locationAudience = locParsed.data;
      } else {
        _locationAudience = [];
      }

      // 2. Age-wise views
      final ageUrl = ApiConstant.audienceAgeWise(
        contentId: contentId,
        fromDate: fromDate,
        toDate: toDate,
      );
      final ageRes = await apiHelper.getApi(ageUrl);
      if (ageRes.statusCode >= 200 && ageRes.statusCode < 300) {
        final ageBody = json.decode(ageRes.body);
        final ageParsed = AudienceAnalyticsResponse.fromJson(ageBody);
        _ageAudience = ageParsed.data;
      } else {
        _ageAudience = [];
      }
    } catch (error) {
      debugPrint('Error fetching audience analytics: $error');
      _locationAudience = [];
      _ageAudience = [];
    } finally {
      _isLoadingAudienceAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> uploadVideoWeb(context, bool isTrailer) async {
    await uploadVideoWebByType(context, isTrailer ? "trailer" : "movie");
  }

  Future<void> uploadVideoWebByType(context, String videoType) async {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'video/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      if (file == null) {
        if (videoType == "trailer") {
          _isTrailerUploading = false;
          trailerUploadProgress = 0.0;
        } else if (videoType == "teaser") {
          _isTeaserUploading = false;
          teaserUploadProgress = 0.0;
        } else {
          _isMovieUploading = false;
          movieUploadProgress = 0.0;
        }
        _isUploading = false;
        notifyListeners();
        return;
      }

      if (videoType == "movie") {
        primarySelectedFile = file;
        movieFileName = file.name;
        movieUploadProgress = 0.0;
        _isMovieUploading = false;
        _isUploading = false;

        final ext = file.name.contains('.') ? file.name.split('.').last : '';
        final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(2);
        final sizeGb = (file.size / (1024 * 1024 * 1024)).toStringAsFixed(3);
        final cType = file.type.isNotEmpty ? file.type : 'video/mp4';

        debugPrint('''
========== MOVIE FILE SELECTED ==========
fileName: ${file.name}
fileSize: ${file.size}
fileSizeMB: ${sizeMb} MB
fileSizeGB: ${sizeGb} GB
contentType: $cType
extension: $ext
hasBytes: false
bytesLength: null
==========================================''');

        notifyListeners();

        final cId = (_activeContentId != null &&
                _activeContentId!.isNotEmpty &&
                _activeContentId != "0")
            ? _activeContentId!
            : "1001";

        await startPrimaryMultipartUpload(
          file: file,
          contentId: cId,
          taskId: 'primary_$cId',
        );
        return;
      }

      final xhr = html.HttpRequest();
      final formData = html.FormData();

      final videoMimeType = file.type.isNotEmpty
          ? file.type
          : _videoMimeTypeForFileName(file.name);
      final typedFile = html.Blob([file], videoMimeType);
      formData.appendBlob('file', typedFile, file.name);

      xhr.upload.onProgress.listen((e) {
        if (e.lengthComputable == true &&
            e.loaded != null &&
            e.total != null &&
            e.total! > 0) {
          final progress = e.loaded! / e.total!;
          if (videoType == "trailer") {
            trailerUploadProgress = progress;
          } else if (videoType == "teaser") {
            teaserUploadProgress = progress;
          } else {
            movieUploadProgress = progress;
          }
          notifyListeners();
        }
      });

      xhr.onLoad.listen((_) {
        if (_isVideoUploadSuccessStatus(xhr.status)) {
          final response = json.decode(xhr.responseText!);
          VideoUploadResponse contentImageUploadResponse =
              VideoUploadResponse.fromJson(response);
          final encryptedUrl = contentImageUploadResponse.data?.fullUrl?.trim();
          if (encryptedUrl == null || encryptedUrl.isEmpty) {
            _resetVideoUploadState(videoType);
            CustomToast.show(
              context,
              _extractUploadErrorMessage(
                xhr.responseText ?? '',
                fallback: 'Upload completed but video URL was missing.',
              ),
              isSuccess: false,
            );
            return;
          }

          if (videoType == "trailer") {
            trailerUrlController.text = encryptedUrl;
            trailerFileName = file.name;
            trailerUploadProgress = 1.0;
            _isTrailerUploading = false;
          } else if (videoType == "teaser") {
            teaserUrlController.text = encryptedUrl;
            teaserFileName = file.name;
            teaserUploadProgress = 1.0;
            _isTeaserUploading = false;
          } else {
            movieUrlController.text = encryptedUrl;
            movieFileName = file.name;
            runTimeController.text =
                (contentImageUploadResponse.data?.duration ?? 0).toString();
            movieUploadProgress = 1.0;
            _isMovieUploading = false;

            primarySelectedFile = file;
            final cId = (_activeContentId != null && _activeContentId!.isNotEmpty && _activeContentId != "0")
                ? _activeContentId!
                : "1001";
            startPrimaryMultipartUpload(
              file: file,
              contentId: cId,
              taskId: 'primary_$cId',
            );
          }
          CustomToast.show(
            context,
            _extractUploadSuccessMessage(
              xhr.responseText ?? '',
              fallback: '${_videoTypeLabel(videoType)} uploaded successfully.',
            ),
            isSuccess: true,
          );
          notifyListeners();
        } else {
          CustomToast.show(
            context,
            _extractUploadErrorMessage(
              xhr.responseText ?? '',
              fallback:
                  '${_videoTypeLabel(videoType)} upload failed with ${xhr.status}.',
            ),
            isSuccess: false,
          );
          _resetVideoUploadState(videoType);
        }
      });

      xhr.onError.listen((_) {
        if (videoType == "trailer") {
          trailerUploadProgress = 0.0;
          _isTrailerUploading = false;
        } else if (videoType == "teaser") {
          teaserUploadProgress = 0.0;
          _isTeaserUploading = false;
        } else {
          movieUploadProgress = 0.0;
          _isMovieUploading = false;
        }
        CustomToast.show(
          context,
          'Network error while uploading ${_videoTypeLabel(videoType).toLowerCase()}.',
          isSuccess: false,
        );
        notifyListeners();
      });
      debugPrint(
          "ApiConstant.uploadVideoMetadata ${ApiConstant.uploadVideoMetadata}");
      xhr.open('POST', ApiConstant.uploadVideoMetadata);
      final headers = await AuthService.authHeaders(includeJson: false);
      headers.forEach(xhr.setRequestHeader);
      xhr.send(formData);

      if (videoType == "trailer") {
        _isTrailerUploading = true;
      } else if (videoType == "teaser") {
        _isTeaserUploading = true;
      } else {
        _isMovieUploading = true;
      }
      notifyListeners();
    });
  }

  Future<void> _uploadSelectedWebVideoFile(
    context,
    String videoType,
    html.File file, {
    String? language,
    String? field,
  }) async {
    final Uri uploadUri = Uri.parse(ApiConstant.uploadVideoMetadata);
    final xhr = html.HttpRequest();
    final formData = html.FormData();

    final videoMimeType = file.type.isNotEmpty
        ? file.type
        : _videoMimeTypeForFileName(file.name);
    final typedFile = html.Blob([file], videoMimeType);
    formData.appendBlob('file', typedFile, file.name);

    xhr.upload.onProgress.listen((e) {
      if (e.lengthComputable == true &&
          e.loaded != null &&
          e.total != null &&
          e.total! > 0) {
        final progress = e.loaded! / e.total!;
        if (videoType == "trailer") {
          trailerUploadProgress = progress;
        } else if (videoType == "teaser") {
          teaserUploadProgress = progress;
        } else {
          movieUploadProgress = progress;
        }
        notifyListeners();
      }
    });

    xhr.onLoad.listen((_) {
      if (_isVideoUploadSuccessStatus(xhr.status)) {
        final response = json.decode(xhr.responseText!);
        VideoUploadResponse contentImageUploadResponse =
            VideoUploadResponse.fromJson(response);
        final encryptedUrl = contentImageUploadResponse.data?.fullUrl?.trim();
        if (encryptedUrl == null || encryptedUrl.isEmpty) {
          _resetVideoUploadState(videoType);
          CustomToast.show(
            context,
            _extractUploadErrorMessage(
              xhr.responseText ?? '',
              fallback: 'Upload completed but video URL was missing.',
            ),
            isSuccess: false,
          );
          return;
        }

        if (videoType == "trailer") {
          trailerUrlController.text = encryptedUrl;
          trailerFileName = file.name;
          trailerUploadProgress = 1.0;
          _isTrailerUploading = false;
          if (language != null && field != null) {
            movieVariantController(language, field).text = encryptedUrl;
          }
        } else if (videoType == "teaser") {
          teaserUrlController.text = encryptedUrl;
          teaserFileName = file.name;
          teaserUploadProgress = 1.0;
          _isTeaserUploading = false;
          if (language != null && field != null) {
            movieVariantController(language, field).text = encryptedUrl;
          }
        }
        CustomToast.show(
          context,
          _extractUploadSuccessMessage(
            xhr.responseText ?? '',
            fallback: '${_videoTypeLabel(videoType)} uploaded successfully.',
          ),
          isSuccess: true,
        );
        notifyListeners();
      } else {
        CustomToast.show(
          context,
          _extractUploadErrorMessage(
            xhr.responseText ?? '',
            fallback:
                '${_videoTypeLabel(videoType)} upload failed with ${xhr.status}.',
          ),
          isSuccess: false,
        );
        _resetVideoUploadState(videoType);
      }
    });

    xhr.onError.listen((_) {
      _resetVideoUploadState(videoType);
      CustomToast.show(
        context,
        '${_videoTypeLabel(videoType)} upload failed. Check network connection.',
        isSuccess: false,
      );
    });

    try {
      final headers = await AuthService.authHeaders(includeJson: false);
      xhr.open('POST', uploadUri.toString());
      headers.forEach(xhr.setRequestHeader);
      xhr.send(formData);
    } catch (e) {
      _resetVideoUploadState(videoType);
      CustomToast.show(
        context,
        'Failed to start upload: $e',
        isSuccess: false,
      );
    }
  }

  Future<void> uploadVideo(bool isTrailer) async {
    await uploadVideoByType(context, isTrailer ? "trailer" : "movie");
  }

  Future<void> uploadVideoByLabel(String label) async {
    if (label == "Trailer File") {
      await uploadVideoByType(context, "trailer");
    } else if (label == "Teaser File") {
      await uploadVideoByType(context, "teaser");
    } else {
      await uploadVideoByType(context, "movie");
    }
  }

  Future<void> uploadVideoByType(context, String videoType) async {
    final Uri uploadUri = Uri.parse(ApiConstant.uploadVideoMetadata);

    try {
      if (kIsWeb) {
        uploadVideoWebByType(context, videoType);
        return;
      } else {
        if (videoType == "trailer") {
          trailerUploadProgress = 0.0;
          _isTrailerUploading = true;
        } else if (videoType == "teaser") {
          teaserUploadProgress = 0.0;
          _isTeaserUploading = true;
        } else {
          movieUploadProgress = 0.0;
          _isMovieUploading = true;
        }
        _isUploading = true;
        notifyListeners();

        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

        if (pickedFile != null) {
          final File file = File(pickedFile.path);
          final totalBytes = await file.length();

          print("Starting upload for $videoType, file size: $totalBytes bytes");

          final StreamController<List<int>> streamController =
              StreamController<List<int>>();
          int bytesSent = 0;

          final progressStream = file.openRead().transform(
                StreamTransformer.fromHandlers(
                  handleData: (List<int> data, EventSink<List<int>> sink) {
                    bytesSent += data.length;
                    final progress = bytesSent / totalBytes;

                    if (videoType == "trailer") {
                      trailerUploadProgress = progress;
                    } else if (videoType == "teaser") {
                      teaserUploadProgress = progress;
                    } else {
                      movieUploadProgress = progress;
                    }

                    print(
                        "Upload progress: ${(progress * 100).toStringAsFixed(1)}%");
                    notifyListeners();

                    sink.add(data);
                  },
                  handleError: (error, stackTrace, sink) {
                    print("Stream error: $error");
                    sink.addError(error, stackTrace);
                  },
                  handleDone: (sink) {
                    print("Stream done");
                    sink.close();
                  },
                ),
              );

          final request = http.MultipartRequest('POST', uploadUri);
          request.headers.addAll(
            await AuthService.authHeaders(includeJson: false),
          );

          request.files.add(http.MultipartFile(
            'file',
            progressStream,
            totalBytes,
            filename: pickedFile.name,
            contentType: _videoMediaTypeForFileName(pickedFile.name),
          ));

          print("Sending request...");
          final response = await request.send();

          if (_isVideoUploadSuccessStatus(response.statusCode)) {
            final responseBody = await response.stream.bytesToString();
            final responseJson = json.decode(responseBody);
            VideoUploadResponse contentImageUploadResponse =
                VideoUploadResponse.fromJson(responseJson);
            final encryptedUrl =
                contentImageUploadResponse.data?.fullUrl?.trim();

            if (encryptedUrl == null || encryptedUrl.isEmpty) {
              print("Video upload response did not include a videoUrl");
              CustomToast.show(
                context,
                _extractUploadErrorMessage(
                  responseBody,
                  fallback: 'Upload completed but video URL was missing.',
                ),
                isSuccess: false,
              );
              if (videoType == "trailer") {
                trailerUploadProgress = 0.0;
              } else if (videoType == "teaser") {
                teaserUploadProgress = 0.0;
              } else {
                movieUploadProgress = 0.0;
              }
              return;
            }

            if (videoType == "trailer") {
              trailerUrlController.text = encryptedUrl;
              trailerFileName = pickedFile.name;
              trailerUploadProgress = 1.0;
            } else if (videoType == "teaser") {
              teaserUrlController.text = encryptedUrl;
              teaserFileName = pickedFile.name;
              teaserUploadProgress = 1.0;
            } else {
              movieUrlController.text = encryptedUrl;
              movieFileName = pickedFile.name;
              runTimeController.text =
                  (contentImageUploadResponse.data?.duration ?? 0).toString();
              movieUploadProgress = 1.0;
            }

            print("Video uploaded successfully: $encryptedUrl");
            CustomToast.show(
              context,
              _extractUploadSuccessMessage(
                responseBody,
                fallback:
                    '${_videoTypeLabel(videoType)} uploaded successfully.',
              ),
              isSuccess: true,
            );
          } else {
            print("Video upload failed with status: ${response.statusCode}");
            final responseBody = await response.stream.bytesToString();
            print("Error response: $responseBody");
            CustomToast.show(
              context,
              _extractUploadErrorMessage(
                responseBody,
                fallback:
                    '${_videoTypeLabel(videoType)} upload failed with ${response.statusCode}.',
              ),
              isSuccess: false,
            );

            if (videoType == "trailer") {
              trailerUploadProgress = 0.0;
            } else if (videoType == "teaser") {
              teaserUploadProgress = 0.0;
            } else {
              movieUploadProgress = 0.0;
            }
          }
          if (videoType == "trailer") {
            _isTrailerUploading = false;
          } else if (videoType == "teaser") {
            _isTeaserUploading = false;
          } else {
            _isMovieUploading = false;
          }
          _isUploading = false;
          notifyListeners();
        } else {
          print("No video selected");
          if (videoType == "trailer") {
            trailerUploadProgress = 0.0;
          } else if (videoType == "teaser") {
            teaserUploadProgress = 0.0;
          } else {
            movieUploadProgress = 0.0;
          }
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error uploading video: $e');
      if (videoType == "trailer") {
        trailerUploadProgress = 0.0;
      } else if (videoType == "teaser") {
        teaserUploadProgress = 0.0;
      } else {
        movieUploadProgress = 0.0;
      }
      notifyListeners();
    } finally {
      if (!kIsWeb) {
        if (videoType == "trailer") {
          _isTrailerUploading = false;
        } else if (videoType == "teaser") {
          _isTeaserUploading = false;
        } else {
          _isMovieUploading = false;
        }
        _isUploading = false;
        notifyListeners();
      }
    }
  }

  bool _isVideoUploadSuccessStatus(int? statusCode) {
    return statusCode == 200 || statusCode == 201 || statusCode == 202;
  }

  String _videoTypeLabel(String videoType) {
    switch (videoType) {
      case "trailer":
        return "Trailer";
      case "teaser":
        return "Teaser";
      default:
        return "Movie";
    }
  }

  String _variantFieldLabel(String field) {
    switch (field) {
      case "trailer":
        return "Trailer";
      case "teaser":
        return "Teaser";
      case "movie":
        return "Movie";
      default:
        return "Video";
    }
  }

  MediaType _videoMediaTypeForFileName(String fileName) {
    final mimeType = _videoMimeTypeForFileName(fileName);
    final parts = mimeType.split('/');
    return MediaType(parts[0], parts[1]);
  }

  String _videoMimeTypeForFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  void _resetVideoUploadState(String videoType) {
    if (videoType == "trailer") {
      trailerUploadProgress = 0.0;
      _isTrailerUploading = false;
    } else if (videoType == "teaser") {
      teaserUploadProgress = 0.0;
      _isTeaserUploading = false;
    } else {
      movieUploadProgress = 0.0;
      _isMovieUploading = false;
    }
    _isUploading = false;
    notifyListeners();
  }

  bool get isVideoUploading =>
      _isTrailerUploading || _isTeaserUploading || _isMovieUploading;

  bool isSpecificVideoUploading(bool isTrailer) {
    return isTrailer ? _isTrailerUploading : _isMovieUploading;
  }

  double getVideoUploadProgress(bool isTrailer) {
    return isTrailer ? trailerUploadProgress : movieUploadProgress;
  }

  void resetVideoUploadProgress(bool isTrailer) {
    if (isTrailer) {
      trailerUploadProgress = 0.0;
      _isTrailerUploading = false;
    } else {
      movieUploadProgress = 0.0;
      _isMovieUploading = false;
    }
    notifyListeners();
  }

  void disposeData() {
    videoController.clear();
    ageRatingController.clear();
    statusController.clear();
    descriptionController.clear();
    movieUrlController.clear();
    teaserUrlController.clear();
    trailerUrlController.clear();
    priceController.clear();
    releaseDateController.clear();
    rentlDurationController.clear();
    censorCertificateController.clear();
    titleController.clear();
    reasonController.clear();
    typeController.clear();
    runTimeController.clear();
    numberOfAttemptController.clear();
    fullAttemptController.clear();
    poster1Controller.clear();
    poster2Controller.clear();
    poster3Controller.clear();
    castController.clear();
    directorController.clear();
    castNameController.clear();
    castRoleController.clear();
    castDescriptionController.clear();
    castImageController.clear();
    crewNameController.clear();
    crewRoleController.clear();
    crewImageController.clear();
    rentalDurationController.clear();
    registrationFeeDetailsController.clear();
    registrationPaymentIdController.clear();
    registrationPaymentDateController.clear();
    registrationAmountPaidController.clear();
    registrationPlanTypeController.clear();
    registrationValidityController.clear();
    registrationPaymentMethodController.clear();
    agreementDocumentUrlController.clear();
    agreementSignedDateController.clear();

    trailerUploadProgress = 0.0;
    teaserUploadProgress = 0.0;
    movieUploadProgress = 0.0;
    censorUploadProgress = 0.0;
    poster1UploadProgress = 0.0;
    poster2UploadProgress = 0.0;
    poster3UploadProgress = 0.0;
    castImageUploadProgress = 0.0;
    crewImageUploadProgress = 0.0;

    _isTrailerUploading = false;
    _isTeaserUploading = false;
    _isMovieUploading = false;
    _isCensorUploading = false;
    _isPoster1Uploading = false;
    _isPoster2Uploading = false;
    _isPoster3Uploading = false;
    _isCastImageUploading = false;
    _isCrewImageUploading = false;
    teaserFileName = null;
    trailerFileName = null;
    movieFileName = null;

    _selectedItems.clear();
    _selectedGeners.clear();
    _selectedAudioFormat.clear();
    _selectedLanguages.clear();
    _selectedSubLanguages.clear();
    _castList.clear();
    _directorList.clear();
    _pendingCasts.clear();
    _pendingCrews.clear();
    _contentCastList = [];

    _audioLanguages.clear();
    _audioUploadProgress.clear();
    _isAudioUploading.clear();
    for (final controller in audioControllers.values) {
      controller.dispose();
    }
    audioControllers.clear();
    for (final variant in _movieVariantControllers.values) {
      for (final controller in variant.values) {
        controller.dispose();
      }
    }
    _movieVariantControllers.clear();
    _movieVariantDurations.clear();
    _movieVariantUploadProgress.clear();
    _movieVariantUploading.clear();

    _isDownloadable = false;
    _isRegistrationFeePaid = false;
    _activeRegistrationFee = null;
    _activeRegistrationFeeContentType = null;
    _activeRegistrationFeeAudienceScope = null;
    _activeRegistrationFeeRemarks = null;
    _isRegistrationFeeLoading = false;
    _registrationFeeError = null;
    _isFeatured = false;
    _isAgreementUploading = false;
    _agreementUploadProgress = 0.0;
    _agreementFileName = null;

    notifyListeners();
  }

  void prepareUploadForm(String type) {
    disposeData();
    typeController.text = type;
    notifyListeners();
  }

  setDate(DateTime pickedDate) {
    releaseDateController.text = pickedDate.toLocal().toString().split(' ')[0];
    notifyListeners();
  }

  Future<void> pickAudioFile(context, String label) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'aac', 'm4a'],
      withData: kIsWeb,
    );
    if (result != null) {
      final language = label.replaceAll(" Audio", "");
      _isAudioUploading[language] = true;
      _audioUploadProgress[language] = 0.0;
      notifyListeners();

      try {
        final pickedFile = result.files.single;
        final extension = (pickedFile.extension ?? '').toLowerCase();
        final sizeInMb = pickedFile.size / (1024 * 1024);
        if (!const {'mp3', 'wav', 'aac', 'm4a'}.contains(extension)) {
          CustomToast.show(
            context,
            'Audio must be MP3, WAV, AAC, or M4A.',
            isSuccess: false,
          );
          return;
        }
        if (sizeInMb > 100) {
          CustomToast.show(context, 'Audio must be 100 MB or smaller.',
              isSuccess: false);
          return;
        }
        final authHdrs = await AuthService.authHeaders(includeJson: false);
        final copyHdrs = Map<String, String>.from(authHdrs);
        if (copyHdrs.containsKey('Authorization')) {
          copyHdrs['Authorization'] = 'Bearer ***REDACTED***';
        }

        debugPrint('''
========== AUDIO METADATA REQUEST ==========
URL: ${ApiConstant.uploadAudioMetadata}
METHOD: POST
HEADERS: $copyHdrs
FILENAME: ${pickedFile.name}
=============================================''');

        final request = http.MultipartRequest(
          'POST',
          Uri.parse(ApiConstant.uploadAudioMetadata),
        );
        request.headers.addAll(authHdrs);

        if (kIsWeb) {
          final bytes = pickedFile.bytes;
          if (bytes == null) {
            throw Exception('Unable to read selected audio file.');
          }
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: pickedFile.name,
            ),
          );
        } else {
          final path = pickedFile.path;
          if (path == null || path.isEmpty) {
            throw Exception('Unable to read selected audio file.');
          }
          request.files.add(await http.MultipartFile.fromPath('file', path));
        }

        _audioUploadProgress[language] = 0.45;
        notifyListeners();

        final response = await request.send();
        final responseBody = await response.stream.bytesToString();

        debugPrint('''
========== AUDIO METADATA RESPONSE ==========
STATUS: ${response.statusCode}
BODY: $responseBody
==============================================''');

        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final uploadResponse = AudioUploadResponse.fromJson(decoded);
        if (response.statusCode != 200 &&
            response.statusCode != 201 &&
            response.statusCode != 202) {
          throw Exception(
            uploadResponse.message?.trim().isNotEmpty == true
                ? uploadResponse.message!.trim()
                : 'Audio upload failed with ${response.statusCode}.',
          );
        }
        if (uploadResponse.success != true) {
          throw Exception(
            uploadResponse.message?.trim().isNotEmpty == true
                ? uploadResponse.message!.trim()
                : 'Audio upload failed.',
          );
        }

        final audioUrl = uploadResponse.data?.fullUrl?.trim();
        if (audioUrl == null || audioUrl.isEmpty) {
          throw Exception('Audio upload response did not include a URL.');
        }

        audioControllers[language]?.text = audioUrl;
        _setLanguageAudioUrl(language, audioUrl);
        _audioUploadProgress[language] = 1.0;
        CustomToast.show(
          context,
          uploadResponse.message?.trim().isNotEmpty == true
              ? uploadResponse.message!.trim()
              : "$label uploaded successfully!",
          isSuccess: true,
        );
      } catch (error) {
        _audioUploadProgress[language] = 0.0;
        CustomToast.show(
            context, 'Unable to upload the audio. Please try again.',
            isSuccess: false);
      } finally {
        _isAudioUploading[language] = false;
        notifyListeners();
      }
    } else {
      CustomToast.show(context, "Audio picking cancelled or failed.",
          isSuccess: false);
    }
  }

  void addAudioLanguage(context, String language) {
    if (!_audioLanguages.contains(language)) {
      _audioLanguages.add(language);
      audioControllers[language] = TextEditingController();
      _isAudioUploading[language] = false;
      _audioUploadProgress[language] = 0.0;
      notifyListeners();
    } else {
      CustomToast.show(context, "$language audio already added.",
          isWarning: true);
    }
  }

  void removeAudioLanguage(String language) {
    _audioLanguages.remove(language);
    audioControllers[language]?.dispose();
    audioControllers.remove(language);
    _isAudioUploading.remove(language);
    _audioUploadProgress.remove(language);
    _selectedLanguages.removeWhere((item) => item.language == language);
    notifyListeners();
  }

  void setSelectedGeners(List<String> items) {
    _selectedGeners = items;
    notifyListeners();
  }

  void setSelectedAudioFormat(List<String> items) {
    _selectedAudioFormat = items;
    notifyListeners();
  }

  void setSelectedSubLanguages(List<String> items) {
    _selectedSubLanguages = items;
    notifyListeners();
  }

  Future<void> fetchGroupedLanguages({bool force = false}) async {
    if (_languageOptionsRequest != null) return _languageOptionsRequest!;
    if (!force && _groupedLanguageOptions.isNotEmpty) return;

    _isLanguageOptionsLoading = true;
    _languageOptionsError = null;
    notifyListeners();

    _languageOptionsRequest = () async {
      try {
        final apiHelper = ApiHelper();
        final response =
            await apiHelper.getApi(ApiConstant.allLanguagesWithGrouping);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Language API failed with status ${response.statusCode}',
          );
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw Exception('Language API returned invalid data');
        }
        _groupedLanguageOptions =
            LanguageGroupResponse.fromJson(decoded).toGroupedNames();
      } catch (error) {
        _languageOptionsError = 'Failed to load languages';
        debugPrint('Language Fetch Error -> $error');
      } finally {
        _isLanguageOptionsLoading = false;
        _languageOptionsRequest = null;
        notifyListeners();
      }
    }();

    return _languageOptionsRequest!;
  }

  void setSelectedLanguages(List<String> items) {
    final existingUrls = {
      for (final language in _selectedLanguages)
        if ((language.language ?? '').trim().isNotEmpty)
          language.language!: language.fileUrl ?? '',
    };
    _selectedLanguages = items
        .where((item) => item.trim().isNotEmpty)
        .map(
          (item) => LanguageList(
            language: item,
            fileUrl: existingUrls[item] ?? '',
          ),
        )
        .toList();
    _syncAudioLanguagesWithSelectedLanguages();
    notifyListeners();
  }

  void clearAudioFile(String language) {
    audioControllers[language]?.clear();
    _setLanguageAudioUrl(language, '');
    notifyListeners();
  }

  void _setLanguageAudioUrl(String language, String audioUrl) {
    final index = _selectedLanguages.indexWhere(
      (item) => item.language == language,
    );
    if (index < 0) return;
    _selectedLanguages[index].fileUrl = audioUrl;
  }

  void _syncAudioLanguagesWithSelectedLanguages() {
    final selectedLanguageNames = _selectedLanguages
        .map((item) => (item.language ?? '').trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final removedLanguages = _audioLanguages
        .where((language) => !selectedLanguageNames.contains(language))
        .toList();
    for (final language in removedLanguages) {
      _audioLanguages.remove(language);
      audioControllers[language]?.dispose();
      audioControllers.remove(language);
      _isAudioUploading.remove(language);
      _audioUploadProgress.remove(language);
    }

    for (final language in selectedLanguageNames) {
      if (!_audioLanguages.contains(language)) {
        _audioLanguages.add(language);
        audioControllers[language] = TextEditingController(
          text: _selectedLanguages
                  .firstWhere((item) => item.language == language)
                  .fileUrl ??
              '',
        );
        _isAudioUploading[language] = false;
        _audioUploadProgress[language] = 0.0;
      } else {
        audioControllers[language]?.text = _selectedLanguages
                .firstWhere((item) => item.language == language)
                .fileUrl ??
            '';
      }
      _movieVariantControllers.putIfAbsent(language, () {
        return {
          'poster1': TextEditingController(),
          'poster2': TextEditingController(),
          'poster3': TextEditingController(),
          'teaser': TextEditingController(),
          'trailer': TextEditingController(),
          'movie': TextEditingController(),
          'subtitle': TextEditingController(),
        };
      });
    }

    final removedVariants = _movieVariantControllers.keys
        .where((language) => !selectedLanguageNames.contains(language))
        .toList();
    for (final language in removedVariants) {
      for (final controller in _movieVariantControllers[language]!.values) {
        controller.dispose();
      }
      _movieVariantControllers.remove(language);
      _movieVariantDurations.remove(language);
      for (final field in const [
        'poster1',
        'poster2',
        'poster3',
        'teaser',
        'trailer',
        'movie',
        'subtitle',
      ]) {
        _movieVariantUploadProgress.remove(_movieVariantKey(language, field));
        _movieVariantUploading.remove(_movieVariantKey(language, field));
      }
    }
  }

  TextEditingController movieVariantController(
    String language,
    String field,
  ) {
    _movieVariantControllers.putIfAbsent(language, () {
      return {
        'poster1': TextEditingController(),
        'poster2': TextEditingController(),
        'poster3': TextEditingController(),
        'teaser': TextEditingController(),
        'trailer': TextEditingController(),
        'movie': TextEditingController(),
        'subtitle': TextEditingController(),
      };
    });
    return _movieVariantControllers[language]![field]!;
  }

  String _movieVariantKey(String language, String field) => '$language::$field';

  double movieVariantUploadProgress(String language, String field) {
    if (field == 'teaser') {
      if (teaserUploadProgressInfo != null && _isTeaserUploading) {
        return (teaserUploadProgressInfo!.percentage / 100.0).clamp(0.0, 1.0);
      }
      return teaserUploadProgress;
    } else if (field == 'trailer') {
      if (trailerUploadProgressInfo != null && _isTrailerUploading) {
        return (trailerUploadProgressInfo!.percentage / 100.0).clamp(0.0, 1.0);
      }
      return trailerUploadProgress;
    } else if ((field == 'movie' || field == 'video') && _isMovieUploading) {
      if (primaryUploadProgressInfo != null) {
        return (primaryUploadProgressInfo!.percentage / 100.0).clamp(0.0, 1.0);
      }
      return movieUploadProgress;
    }
    return _movieVariantUploadProgress[_movieVariantKey(language, field)] ?? 0.0;
  }

  bool isMovieVariantUploading(String language, String field) {
    if (field == 'teaser') {
      return _isTeaserUploading;
    } else if (field == 'trailer') {
      return _isTrailerUploading;
    } else if (field == 'movie' || field == 'video') {
      return _isMovieUploading;
    }
    return _movieVariantUploading[_movieVariantKey(language, field)] ?? false;
  }

  void clearMovieVariant(String language, String field) {
    final controller = movieVariantController(language, field);
    controller.clear();

    final variantKey = _movieVariantKey(language, field);
    _movieVariantUploadProgress[variantKey] = 0.0;
    _movieVariantUploading[variantKey] = false;

    if (field == 'movie' || field == 'video') {
      movieUrlController.clear();
      movieFileName = null;
      _isMovieUploading = false;
      movieUploadProgress = 0.0;
      primaryUploadProgressInfo = null;
      primarySelectedFile = null;
      primaryUploadTask = null;
      _movieVariantDurations.remove(language);
    } else if (field == 'teaser') {
      teaserUrlController.clear();
      teaserFileName = null;
      _isTeaserUploading = false;
      teaserUploadProgress = 0.0;
      teaserUploadProgressInfo = null;
      teaserSelectedFile = null;
      teaserUploadTask = null;
    } else if (field == 'trailer') {
      trailerUrlController.clear();
      trailerFileName = null;
      _isTrailerUploading = false;
      trailerUploadProgress = 0.0;
      trailerUploadProgressInfo = null;
      trailerSelectedFile = null;
      trailerUploadTask = null;
    } else if (field == 'poster1') {
      poster1Controller.clear();
      poster1UploadProgress = 0.0;
    } else if (field == 'poster2') {
      poster2Controller.clear();
      poster2UploadProgress = 0.0;
    } else if (field == 'poster3') {
      poster3Controller.clear();
      poster3UploadProgress = 0.0;
    } else if (field == 'censor') {
      censorCertificateController.clear();
      censorUploadProgress = 0.0;
    } else if (field == 'agreement') {
      agreementDocumentUrlController.clear();
      _agreementFileName = null;
      _agreementUploadProgress = 0.0;
    }

    notifyListeners();
  }

  Future<void> pickMovieVariantFile(
    context,
    String language,
    String field, {
    required bool isVideo,
  }) async {
    final isSubtitle = field == 'subtitle';
    final isImage = field.startsWith('poster');

    if (isVideo && kIsWeb) {
      final html.FileUploadInputElement uploadInput =
          html.FileUploadInputElement()..accept = 'video/*';
      uploadInput.click();

      uploadInput.onChange.listen((event) async {
        final file = uploadInput.files?.first;
        if (file == null) return;

        final cId = (_activeContentId != null &&
                _activeContentId!.isNotEmpty &&
                _activeContentId != "0")
            ? _activeContentId!
            : "1001";

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (field == 'teaser') {
          await startTeaserMultipartUpload(
            file: file,
            contentId: cId,
            taskId: 'teaser_${cId}_$timestamp',
            language: language,
            field: field,
          );
        } else if (field == 'trailer') {
          await startTrailerMultipartUpload(
            file: file,
            contentId: cId,
            taskId: 'trailer_${cId}_$timestamp',
            language: language,
            field: field,
          );
        } else {
          await startPrimaryMultipartUpload(
            file: file,
            contentId: cId,
            taskId: 'primary_${cId}_$timestamp',
            language: language,
            field: field,
          );
        }
      });
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: isVideo ? FileType.video : FileType.custom,
      allowedExtensions: isVideo
          ? null
          : isSubtitle
              ? const ['srt', 'vtt']
              : ImageValidationConstants.commonImageFormats,
      withData: kIsWeb && !isVideo,
    );
    if (result == null) return;

    try {
      final variantKey = _movieVariantKey(language, field);
      _movieVariantUploading[variantKey] = true;
      _movieVariantUploadProgress[variantKey] = 0.05;
      notifyListeners();

      final pickedFile = result.files.single;
      final validationError = await _validateMovieVariantFile(
        pickedFile,
        isVideo: isVideo,
        isImage: isImage,
        isSubtitle: isSubtitle,
      );
      if (validationError != null) {
        CustomToast.show(context, validationError, isSuccess: false);
        return;
      }
      debugPrint(
          "ApiConstant.uploadVideoMetadata ${ApiConstant.uploadVideoMetadata}");
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          isVideo
              ? ApiConstant.uploadVideoMetadata
              : isSubtitle
                  ? ApiConstant.uploadSubtitle
                  : ApiConstant.uploadImg,
        ),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );

      if (kIsWeb) {
        final bytes = pickedFile.bytes;
        if (bytes == null) throw Exception('Unable to read selected file.');
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
            contentType:
                isVideo ? _videoMediaTypeForFileName(pickedFile.name) : null,
          ),
        );
      } else {
        final path = pickedFile.path;
        if (path == null || path.isEmpty) {
          throw Exception('Unable to read selected file.');
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            path,
            contentType:
                isVideo ? _videoMediaTypeForFileName(pickedFile.name) : null,
          ),
        );
      }

      _movieVariantUploadProgress[variantKey] = 0.35;
      notifyListeners();

      final response = await request.send();
      print(request);
      _movieVariantUploadProgress[variantKey] = 0.8;
      notifyListeners();
      final body = await response.stream.bytesToString();
      print(body);
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 202) {
        throw Exception(
          _extractUploadErrorMessage(
            body,
            fallback: isSubtitle
                ? 'Subtitle upload failed with ${response.statusCode}.'
                : 'Upload failed with ${response.statusCode}.',
          ),
        );
      }

      final decoded = jsonDecode(body);
      final videoResponse =
          isVideo ? VideoUploadResponse.fromJson(decoded) : null;
      String? url;
      if (isVideo) {
        url = videoResponse?.data?.fullUrl;
      } else if (isSubtitle) {
        url = decoded['data']?['fileUrl']?.toString();
      } else {
        url = ContentImageUploadResponse.fromJson(decoded).data?.fileUrl;
      }

      if (url == null || url.trim().isEmpty) {
        throw Exception(
          isSubtitle
              ? 'Subtitle uploaded, but the server did not return a file URL.'
              : 'Upload response did not include a URL.',
        );
      }
      movieVariantController(language, field).text = url.trim();
      if (field == 'teaser') {
        teaserUrlController.text = url.trim();
      } else if (field == 'trailer') {
        trailerUrlController.text = url.trim();
      } else if (field == 'movie') {
        movieUrlController.text = url.trim();
        movieFileName = pickedFile.name;
        final durationInSeconds = videoResponse?.data?.duration ?? 0;
        _movieVariantDurations[language] = durationInSeconds;
        // Keep the shared controller in sync for agreement generation and any
        // older flows that still read the runtime value.
        runTimeController.text = durationInSeconds.toString();
      }
      _movieVariantUploadProgress[variantKey] = 1.0;
      notifyListeners();
      if (isSubtitle) {
        CustomToast.show(
          context,
          (decoded['message']?.toString().trim().isNotEmpty ?? false)
              ? decoded['message'].toString().trim()
              : 'Subtitle uploaded successfully.',
          isSuccess: true,
        );
      } else if (isVideo) {
        CustomToast.show(
          context,
          _extractUploadSuccessMessage(
            body,
            fallback: '${_variantFieldLabel(field)} uploaded successfully.',
          ),
          isSuccess: true,
        );
      }
    } catch (error) {
      _movieVariantUploadProgress[_movieVariantKey(language, field)] = 0.0;
      final message =
          error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      CustomToast.show(context, message, isSuccess: false);
    } finally {
      _movieVariantUploading[_movieVariantKey(language, field)] = false;
      notifyListeners();
    }
  }

  String _extractUploadErrorMessage(
    String body, {
    required String fallback,
  }) {
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

  String _extractUploadSuccessMessage(
    String body, {
    required String fallback,
  }) {
    if (body.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {}
    return fallback;
  }

  Future<String?> _validateMovieVariantFile(
    PlatformFile file, {
    required bool isVideo,
    required bool isImage,
    required bool isSubtitle,
  }) async {
    final extension = (file.extension ?? '').toLowerCase();
    final sizeInMb = file.size / (1024 * 1024);

    if (isVideo) {
      const allowed = {'mp4', 'mov', 'm4v', 'webm'};
      if (!allowed.contains(extension)) {
        return 'Video must be MP4, MOV, M4V, or WEBM.';
      }
      if (sizeInMb > 2048) return 'Video must be 2 GB or smaller.';
      return null;
    }

    if (isImage) {
      final bytes = await _resolvePlatformFileBytes(file);
      if (bytes == null) return 'Unable to read selected image.';
      final validation = await ImageValidationService.validateBytes(
        bytes: bytes,
        fileName: file.name,
        sizeInBytes: file.size,
        type: ImageValidationType.poster,
      );
      return validation.isValid ? null : validation.message;
    }

    if (isSubtitle) {
      const allowed = {'srt', 'vtt'};
      if (!allowed.contains(extension)) {
        return 'Subtitle must be SRT or VTT.';
      }
      if (sizeInMb > 2) return 'Subtitle file must be 2 MB or smaller.';
    }
    return null;
  }

  ImageValidationType _imageValidationTypeForLabel(String label) {
    return label.startsWith('Poster')
        ? ImageValidationType.poster
        : ImageValidationType.general;
  }

  Future<Uint8List?> _resolvePlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return io.File(path).readAsBytes();
  }

  Future<Map<String, bool>> uploadMovieVariants(BuildContext context) async {
    if (_isSavingContent) return {};
    _isSavingContent = true;
    notifyListeners();

    try {
      final localSharePreferences = LocalSharePreferences();
      final mediaHouse = await localSharePreferences.getMediaHouse();
      if (mediaHouse == null) {
        CustomToast.show(context, "Production house not found.",
            isSuccess: false);
        return {};
      }

      if (hasIncompleteCastDraft) {
        CustomToast.show(
          context,
          "Please complete current cast details before submit.",
          isSuccess: false,
        );
        return {
          for (final language in selectedLanguages)
            if ((language.language ?? '').trim().isNotEmpty)
              (language.language ?? '').trim(): false,
        };
      }

      final castPayloads = List<Map<String, String>>.from(_pendingCasts);
      if (hasCastDraft) {
        castPayloads.add(_buildCastFromControllers());
      }

      final crewPayloads = List<Map<String, String>>.from(_pendingCrews);
      if (hasCrewDraft) {
        final crewDraft = _buildCrewFromControllers();
        if ((crewDraft["name"] ?? "").isEmpty ||
            (crewDraft["role"] ?? "").isEmpty) {
          CustomToast.show(
            context,
            "Please complete the crew name and role before submitting.",
            isSuccess: false,
          );
          return {
            for (final language in selectedLanguages)
              if ((language.language ?? '').trim().isNotEmpty)
                (language.language ?? '').trim(): false,
          };
        }
        crewPayloads.add(crewDraft);
      }

      final results = <String, bool>{};
      for (final language in selectedLanguages) {
        final name = (language.language ?? '').trim();
        if (name.isEmpty) continue;
        final variant = _movieVariantControllers[name];
        if (variant == null) {
          results[name] = false;
          continue;
        }

        final saveContent = SaveContentRequest()
          ..id = 0
          ..ageRating = ageRatingController.text
          ..aggrementDocument = agreementDocumentUrl
          ..approvalStatus = derivedApprovalStatus
          ..approvedDateTime = ''
          ..audioFormatList = selectedAudioFormat
          ..availability = Availability()
          ..castList = castList
          ..contentUrl = variant['movie']!.text
          ..directorList = directorList
          ..description = descriptionController.text
          ..genersList = selectedGeners
          ..isAggrement = hasUploadedAgreement
          ..isDownloadable = isDownloadable
          ..isFeatured = isFeatured
          ..isPaid = isRegistrationFeePaid
          ..isReadyForApproval = isReadyForApprovalValue
          ..registrationFeePaid = registrationFeePaidValue
          ..registrationFeeDetails = registrationFeeDetailsValue
          ..languageList = [
            LanguageList(language: name, fileUrl: language.fileUrl ?? ''),
          ]
          ..mediaHouseId = mediaHouse.id!
          ..price = double.tryParse(priceController.text) ?? 0.0
          ..posterUrlList = [
            variant['poster1']!.text,
            variant['poster2']!.text,
            variant['poster3']!.text,
          ]
          ..ratings = 0
          ..ratingCount = 0
          ..reason = ''
          ..releaseDate = releaseDateController.text
          ..releaseTime = ''
          ..rentlDuration = rentalDurationController.text.isNotEmpty
              ? rentalDurationController.text
              : rentlDurationController.text
          ..totalRevenue = 0
          ..runtime = (_movieVariantDurations[name] ?? 0).toDouble()
          ..numberOfAttempt =
              int.tryParse(numberOfAttemptController.text.trim()) ?? 0
          ..fullAttempt = int.tryParse(fullAttemptController.text.trim()) ?? 0
          ..subtitleLanguageList =
              variant['subtitle']!.text.isEmpty ? [] : [variant['subtitle']!.text]
          ..sensorCertificate = censorCertificateController.text
          ..type = typeController.text
          ..title = titleController.text
          ..teaserUrl = variant['teaser']!.text
          ..trailerUrl = variant['trailer']!.text
          ..uploadDateTime = DateTime.now().toUtc().toIso8601String()
          ..views = 0;

        try {
          final response = await ApiHelper()
              .postApiWithBody(ApiConstant.saveVideo, saveContent.toJson());
          if (response.statusCode == 200) {
            final parsed = AddVideoResponse.fromJson(jsonDecode(response.body));
            var saved = parsed.isSuccess == true;
            final contentId = parsed.data?.id;
            if (saved && contentId != null) {
              saved = await _saveCastAndCrewPayloadsForContent(
                contentId: contentId,
                casts: castPayloads,
                crews: crewPayloads,
              );
            } else if (saved) {
              saved = false;
            }
            results[name] = saved;
          } else {
            results[name] = false;
          }
        } catch (_) {
          results[name] = false;
        }
      }

      if (results.values.any((success) => success)) {
        fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
      }
      return results;
    } finally {
      _isSavingContent = false;
      notifyListeners();
    }
  }

  Future<Map<String, bool>> uploadSeriesVariants(BuildContext context) async {
    if (_isSavingContent) return {};
    _isSavingContent = true;
    notifyListeners();

    try {
      final localSharePreferences = LocalSharePreferences();
      final mediaHouse = await localSharePreferences.getMediaHouse();
      if (mediaHouse == null) {
        CustomToast.show(context, "Production house not found.",
            isSuccess: false);
        return {};
      }

      if (hasIncompleteCastDraft) {
        CustomToast.show(
          context,
          "Please complete current cast details before submit.",
          isSuccess: false,
        );
        return {
          for (final language in selectedLanguages)
            if ((language.language ?? '').trim().isNotEmpty)
              (language.language ?? '').trim(): false,
        };
      }

      final castPayloads = List<Map<String, String>>.from(_pendingCasts);
      if (hasCastDraft) {
        castPayloads.add(_buildCastFromControllers());
      }

      final crewPayloads = List<Map<String, String>>.from(_pendingCrews);
      if (hasCrewDraft) {
        final crewDraft = _buildCrewFromControllers();
        if ((crewDraft["name"] ?? "").isEmpty ||
            (crewDraft["role"] ?? "").isEmpty) {
          CustomToast.show(
            context,
            "Please complete the crew name and role before submitting.",
            isSuccess: false,
          );
          return {
            for (final language in selectedLanguages)
              if ((language.language ?? '').trim().isNotEmpty)
                (language.language ?? '').trim(): false,
          };
        }
        crewPayloads.add(crewDraft);
      }

      final results = <String, bool>{};
      for (final language in selectedLanguages) {
        final name = (language.language ?? '').trim();
        if (name.isEmpty) continue;
        final variant = _movieVariantControllers[name];
        if (variant == null) {
          results[name] = false;
          continue;
        }

        final saveContent = SaveSeriesRequest()
          ..id = 0
          ..ageRating = ageRatingController.text
          ..aggrementDocument = agreementDocumentUrl
          ..approvalStatus = derivedApprovalStatus
          ..approvedDateTime = ''
          ..audioFormatList = selectedAudioFormat
          ..availability = Availability()
          ..castList = castList
          ..contentUrl = ''
          ..directorList = directorList
          ..description = descriptionController.text
          ..genreList = selectedGeners
          ..isAggrement = hasUploadedAgreement
          ..isDownloadable = isDownloadable
          ..isFeatured = isFeatured
          ..isPaid = isRegistrationFeePaid
          ..isReadyForApproval = isReadyForApprovalValue
          ..registrationFeePaid = registrationFeePaidValue
          ..registrationFeeDetails = registrationFeeDetailsValue
          ..languageList = [
            LanguageList(language: name, fileUrl: ''),
          ]
          ..mediaHouseId = mediaHouse.id!
          ..price = double.tryParse(priceController.text) ?? 0.0
          ..posterUrlList = [
            variant['poster1']!.text,
            variant['poster2']!.text,
            variant['poster3']!.text,
          ]
          ..ratings = 0
          ..ratingCount = 0
          ..reason = ''
          ..releaseDate = releaseDateController.text
          ..releaseTime = ''
          ..rentlDuration = rentalDurationController.text.isNotEmpty
              ? rentalDurationController.text
              : rentlDurationController.text
          ..totalRevenue = 0
          ..runtime = 0
          ..numberOfAttempt =
              int.tryParse(numberOfAttemptController.text.trim()) ?? 0
          ..fullAttempt = int.tryParse(fullAttemptController.text.trim()) ?? 0
          ..subtitleLanguageList = []
          ..sensorCertificate = censorCertificateController.text
          ..title = titleController.text
          ..teaserUrl = variant['teaser']!.text
          ..trailerUrl = variant['trailer']!.text
          ..type = typeController.text
          ..uploadDateTime = DateTime.now().toUtc().toIso8601String()
          ..views = 0;

        try {
          final payload = saveContent.toJson();
          debugPrint("Series Payload: ${json.encode(payload)}");
          final response =
              await ApiHelper().postApiWithBody(ApiConstant.saveSeries, payload);
          if (response.statusCode == 200) {
            final parsed = AddVideoResponse.fromJson(jsonDecode(response.body));
            var saved = parsed.isSuccess == true;
            final contentId = parsed.data?.id;
            if (saved && contentId != null) {
              saved = await _saveCastAndCrewPayloadsForContent(
                contentId: contentId,
                casts: castPayloads,
                crews: crewPayloads,
              );
            } else if (saved) {
              saved = false;
            }
            results[name] = saved;
          } else {
            results[name] = false;
          }
        } catch (error) {
          debugPrint("Series variant upload failed for $name: $error");
          results[name] = false;
        }
      }

      if (results.values.any((success) => success)) {
        fetchMoviesByStatusAndMediaHouseId("All", mediaHouse.id!);
      }
      return results;
    } finally {
      _isSavingContent = false;
      notifyListeners();
    }
  }

  Future<bool> _saveCastAndCrewPayloadsForContent({
    required int contentId,
    required List<Map<String, String>> casts,
    required List<Map<String, String>> crews,
  }) async {
    for (final cast in casts) {
      final saved = await _saveSingleCastPayload(
        context,
        contentId: contentId,
        seasonId: 0,
        cast: cast,
      );
      if (!saved) return false;
    }

    for (final crew in crews) {
      final payload = {
        "name": (crew["name"] ?? "").trim(),
        "role": (crew["role"] ?? "").trim(),
        "image": (crew["image"] ?? "").trim(),
        "description": "",
      };
      final saved = await _saveSingleCastPayload(
        context,
        contentId: contentId,
        seasonId: 0,
        cast: payload,
      );
      if (!saved) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    titleController.dispose();
    descriptionController.dispose();
    releaseDateController.dispose();
    runTimeController.dispose();
    numberOfAttemptController.dispose();
    fullAttemptController.dispose();
    priceController.dispose();
    movieUrlController.dispose();
    trailerUrlController.dispose();
    teaserUrlController.dispose();
    registrationFeeDetailsController.dispose();
    registrationPaymentIdController.dispose();
    registrationPaymentDateController.dispose();
    registrationAmountPaidController.dispose();
    registrationPlanTypeController.dispose();
    registrationValidityController.dispose();
    registrationPaymentMethodController.dispose();
    agreementDocumentUrlController.dispose();
    agreementSignedDateController.dispose();
    censorCertificateController.dispose();
    poster1Controller.dispose();
    poster2Controller.dispose();
    poster3Controller.dispose();
    castController.dispose();
    directorController.dispose();
    castNameController.dispose();
    castRoleController.dispose();
    castDescriptionController.dispose();
    castImageController.dispose();
    crewNameController.dispose();
    crewRoleController.dispose();
    crewImageController.dispose();
    searchContentController.dispose();
    super.dispose();
  }
}

class RatingReviewItem {
  final int? createdAt;
  final int? contentId;
  final int? reviewId;
  final int? userId;
  final int rating;
  final String title;
  final String comment;
  final String username;
  final String userProfile;

  RatingReviewItem({
    required this.createdAt,
    required this.contentId,
    required this.reviewId,
    required this.userId,
    required this.rating,
    required this.title,
    required this.comment,
    required this.username,
    required this.userProfile,
  });

  factory RatingReviewItem.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return RatingReviewItem(
      createdAt: json['createdAt'] is int ? json['createdAt'] as int : null,
      contentId: json['contentId'] is int ? json['contentId'] as int : null,
      reviewId: json['reviewId'] is int ? json['reviewId'] as int : null,
      userId: json['userId'] is int ? json['userId'] as int : null,
      rating: toInt(json['rating']),
      title: (json['title'] ?? '').toString(),
      comment: (json['comment'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      userProfile: (json['userProfile'] ?? '').toString(),
    );
  }
}
