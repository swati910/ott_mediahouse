import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/data/models/shorts.dart';
import 'package:media_house/data/models/response/audio_upload_response.dart';
import 'package:media_house/domain/entities/cast_crew_model.dart';
import 'package:universal_html/html.dart' as html;

import '../../data/models/response/allContentResponse.dart';
import '../../data/models/response/series_detail_response.dart';
import '../../data/models/response/short_detail_response.dart';
import '../../data/models/response/video_upload_response.dart';
import '../../domain/entities/content.dart';
import '../core/auth/auth_service.dart';
import '../core/network/api_helper.dart';
import '../core/utils/sharepreferences.dart';
import '../core/upload/multipart_upload_persistence.dart';
import '../core/upload/s3_multipart_upload_service.dart';
import '../widget/show_toast.dart';

class SeriesProvider extends ChangeNotifier {
  List<ShortModel> shorts = [];
  ShortDetailResponse? shortDetail;
  bool isLoading = false;
  bool _isUploading = false;
  bool _isMovieUploading = false;
  double movieUploadProgress = 0.0;

  bool get isMovieUploading => _isMovieUploading;

  List<Content> _contentList = [];
  List<Content> _filteredContentList = [];
  List<Content> get contentList => _contentList;
  List<Content> get filteredContentList => _filteredContentList;
  int _totalItems = 0;
  int get totalItems => _totalItems;
  static const int _itemsPerPage = 10;
  bool _hasMoreItems = false;
  bool get hasMoreItems => _hasMoreItems;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  int? _statusMediaHouseIdForPagination;
  String _statusValueForPagination = "APPROVED";
  String _statusTypeForPagination = "SERIES";
  String _statusKeywordForPagination = "";
  String? _statusStartDateForPagination;
  String? _statusEndDateForPagination;
  int _statusCurrentPage = 0;
  int _statusTotalPages = 0;
  bool _hasMoreStatusItems = false;
  bool _isStatusLoadingMore = false;
  bool get isStatusLoadingMore => _isStatusLoadingMore;
  final TextEditingController movieUrlController = TextEditingController();
  final TextEditingController episodeAudioUrlController =
      TextEditingController();
  final TextEditingController episodeSubtitleUrlController =
      TextEditingController();
  int episodeVideoRuntime = 0;
  bool _isEpisodeAudioUploading = false;
  bool _isEpisodeSubtitleUploading = false;
  double episodeAudioUploadProgress = 0.0;
  double episodeSubtitleUploadProgress = 0.0;
  String? episodeAudioFileName;
  String? episodeSubtitleFileName;

  bool get isEpisodeAudioUploading => _isEpisodeAudioUploading;
  bool get isEpisodeSubtitleUploading => _isEpisodeSubtitleUploading;

  html.File? episodeSelectedFile;
  final Map<String, S3MultipartUploadTask> _episodeUploadTasks = {};
  final Map<String, MultipartProgressInfo> _episodeUploadProgressInfo = {};

  MultipartProgressInfo? getEpisodeProgressInfo(String taskId) =>
      _episodeUploadProgressInfo[taskId];

  Future<void> startEpisodeMultipartUpload({
    required html.File file,
    required String contentId,
    required String taskId,
  }) async {
    episodeSelectedFile = file;

    final task = S3MultipartUploadTask(
      localTaskId: taskId,
      file: file,
      contentId: contentId,
      onProgress: (info) {
        _episodeUploadProgressInfo[taskId] = info;
        notifyListeners();
      },
    );

    _episodeUploadTasks[taskId] = task;
    await task.startOrResume();
  }

  void pauseEpisodeMultipartUpload(String taskId) {
    _episodeUploadTasks[taskId]?.pause();
  }

  Future<void> resumeEpisodeMultipartUpload(String taskId, {html.File? file}) async {
    final task = _episodeUploadTasks[taskId];
    final targetFile = file ?? episodeSelectedFile;
    if (task != null && targetFile != null) {
      await task.startOrResume(reselectedFile: targetFile);
    }
  }

  Future<void> retryEpisodeMultipartUpload(String taskId) async {
    final task = _episodeUploadTasks[taskId];
    if (task != null && episodeSelectedFile != null) {
      await task.startOrResume(reselectedFile: episodeSelectedFile);
    }
  }

  Future<bool> abortEpisodeMultipartUpload(String taskId, {BuildContext? context}) async {
    final task = _episodeUploadTasks[taskId];
    final success = (await task?.abort()) ?? true;
    if (success) {
      _episodeUploadTasks.remove(taskId);
      _episodeUploadProgressInfo.remove(taskId);
      notifyListeners();
      if (context != null && context.mounted) {
        CustomToast.show(context, "Upload cancelled successfully.", isSuccess: true);
      }
    } else {
      notifyListeners();
      if (context != null && context.mounted) {
        CustomToast.show(context, "Unable to cancel the upload. Please try again.", isSuccess: false);
      }
    }
    return success;
  }

  SeriesDetailsResponse? _data;
  bool _loading = false;
  String? _error;
  bool _isLoadingCastCrew = false;
  String? _castCrewError;
  int? _activeCastCrewContentId;
  int? _activeCastCrewSeasonId;
  List<CastCrewItem> _activeCastCrewList = [];
  final Map<String, List<CastCrewItem>> _castCrewCache = {};

  SeriesDetailsResponse? get data => _data;
  bool get loading => _loading;
  String? get error => _error;
  bool get isLoadingCastCrew => _isLoadingCastCrew;
  String? get castCrewError => _castCrewError;
  int? get activeCastCrewContentId => _activeCastCrewContentId;
  int? get activeCastCrewSeasonId => _activeCastCrewSeasonId;
  List<CastCrewItem> get activeCastCrewList =>
      List.unmodifiable(_activeCastCrewList);
  List<CastCrewItem> get activeCastList =>
      _activeCastCrewList.where((e) => !e.isCrew).toList(growable: false);
  List<CastCrewItem> get activeCrewList =>
      _activeCastCrewList.where((e) => e.isCrew).toList(growable: false);

  Future<void> loadSeries(int seriesId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final url = ApiConstant.seriesDetails(seriesId);
      print(url);
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.getApi(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final Map<String, dynamic> jsonMap = decoded is Map<String, dynamic>
            ? decoded
            : decoded is Map
                ? Map<String, dynamic>.from(decoded)
                : {'data': decoded};
        _data = SeriesDetailsResponse.fromJson(jsonMap);
      } else {
        _error = "Failed to load series (${response.statusCode})";
      }
    } catch (e) {
      _error = "Something went wrong while loading series: $e";
      debugPrint("SeriesProvider error: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clear() {
    _data = null;
    _error = null;
    _loading = false;
    _castCrewError = null;
    _activeCastCrewList = [];
    _activeCastCrewContentId = null;
    _activeCastCrewSeasonId = null;
    _castCrewCache.clear();
    notifyListeners();
  }

  String _castCrewKey(int contentId, int seasonId) => '$contentId-$seasonId';
  String _castCrewContentOnlyKey(int contentId) => '$contentId-content';

  List<CastCrewItem> _parseCastCrewListFromBody(dynamic body) {
    final jsonMap = body is Map<String, dynamic>
        ? body
        : body is Map
            ? Map<String, dynamic>.from(body)
            : <String, dynamic>{};

    dynamic castRaw = jsonMap['data']?['cast'];
    castRaw ??= jsonMap['data']?['castList'];
    castRaw ??= jsonMap['cast'];
    castRaw ??= jsonMap['castList'];
    castRaw ??= jsonMap['data'];

    if (castRaw is! List) return <CastCrewItem>[];

    return castRaw
        .whereType<Map>()
        .map((e) => CastCrewItem.fromJson(
            Map<String, dynamic>.from(e as Map<dynamic, dynamic>)))
        .toList(growable: false);
  }

  Future<void> ensureCastCrewLoaded({
    required int contentId,
    required int seasonId,
  }) async {
    if (_isLoadingCastCrew &&
        _activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == seasonId) {
      return;
    }

    if (_activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == seasonId &&
        _activeCastCrewList.isNotEmpty) {
      return;
    }

    final key = _castCrewKey(contentId, seasonId);
    if (_castCrewCache.containsKey(key)) {
      final cached = _castCrewCache[key]!;
      if (cached.isNotEmpty) {
        _activeCastCrewContentId = contentId;
        _activeCastCrewSeasonId = seasonId;
        _activeCastCrewList = cached;
        notifyListeners();
        return;
      }
    }

    await fetchCastCrewByContentAndSeason(
      contentId: contentId,
      seasonId: seasonId,
    );
  }

  Future<void> ensureCastCrewLoadedForSeasonOnly({
    required int contentId,
    required int seasonId,
  }) async {
    if (_isLoadingCastCrew &&
        _activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == seasonId) {
      return;
    }

    if (_activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == seasonId &&
        _activeCastCrewList.isNotEmpty) {
      return;
    }

    final key = _castCrewKey(contentId, seasonId);
    if (_castCrewCache.containsKey(key)) {
      final cached = _castCrewCache[key]!;
      if (cached.isNotEmpty) {
        _activeCastCrewContentId = contentId;
        _activeCastCrewSeasonId = seasonId;
        _activeCastCrewList = cached;
        notifyListeners();
        return;
      }
    }

    await fetchCastCrewByContentAndSeasonStrict(
      contentId: contentId,
      seasonId: seasonId,
    );
  }

  Future<void> ensureCastCrewLoadedByContent({
    required int contentId,
  }) async {
    if (contentId <= 0) return;

    if (_isLoadingCastCrew &&
        _activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == null) {
      return;
    }

    if (_activeCastCrewContentId == contentId &&
        _activeCastCrewSeasonId == null &&
        _activeCastCrewList.isNotEmpty) {
      return;
    }

    final key = _castCrewContentOnlyKey(contentId);
    if (_castCrewCache.containsKey(key)) {
      final cached = _castCrewCache[key]!;
      if (cached.isNotEmpty) {
        _activeCastCrewContentId = contentId;
        _activeCastCrewSeasonId = null;
        _activeCastCrewList = cached;
        notifyListeners();
        return;
      }
    }

    await fetchCastCrewByContentId(contentId: contentId);
  }

  Future<void> fetchCastCrewByContentAndSeason({
    required int contentId,
    required int seasonId,
  }) async {
    if (contentId <= 0 || seasonId <= 0) return;

    _isLoadingCastCrew = true;
    _castCrewError = null;
    _activeCastCrewContentId = contentId;
    _activeCastCrewSeasonId = seasonId;
    notifyListeners();

    try {
      final apiHelper = ApiHelper();
      final url = ApiConstant.getCastByContentIdAndSeasonId(
        contentId: contentId,
        seasonId: seasonId,
      );
      final response = await apiHelper.getApi(url);
      final body = jsonDecode(response.body);
      var castList = _parseCastCrewListFromBody(body);

      // Fallback: some backends return empty for season endpoint.
      if (castList.isEmpty) {
        final fallbackResponse =
            await apiHelper.getApi(ApiConstant.getCastByContentId(contentId));
        final fallbackBody = jsonDecode(fallbackResponse.body);
        final allCast = _parseCastCrewListFromBody(fallbackBody);
        castList = allCast
            .where((item) =>
                item.seasonId == null ||
                item.seasonId == 0 ||
                item.seasonId == seasonId)
            .toList(growable: false);
      }

      _activeCastCrewList = castList;
      _castCrewCache[_castCrewKey(contentId, seasonId)] = castList;
    } catch (e) {
      try {
        final apiHelper = ApiHelper();
        final fallbackResponse =
            await apiHelper.getApi(ApiConstant.getCastByContentId(contentId));
        final fallbackBody = jsonDecode(fallbackResponse.body);
        final allCast = _parseCastCrewListFromBody(fallbackBody);
        final castList = allCast
            .where((item) =>
                item.seasonId == null ||
                item.seasonId == 0 ||
                item.seasonId == seasonId)
            .toList(growable: false);
        _activeCastCrewList = castList;
        _castCrewCache[_castCrewKey(contentId, seasonId)] = castList;
      } catch (_) {
        _castCrewError = 'Failed to load cast and crew';
        _activeCastCrewList = [];
      }
      debugPrint("Cast/Crew load error: $e");
    } finally {
      _isLoadingCastCrew = false;
      notifyListeners();
    }
  }

  Future<void> fetchCastCrewByContentAndSeasonStrict({
    required int contentId,
    required int seasonId,
  }) async {
    if (contentId <= 0 || seasonId <= 0) return;

    _isLoadingCastCrew = true;
    _castCrewError = null;
    _activeCastCrewContentId = contentId;
    _activeCastCrewSeasonId = seasonId;
    notifyListeners();

    try {
      final apiHelper = ApiHelper();
      final url = ApiConstant.getCastByContentIdAndSeasonId(
        contentId: contentId,
        seasonId: seasonId,
      );
      final response = await apiHelper.getApi(url);
      final body = jsonDecode(response.body);
      var castList = _parseCastCrewListFromBody(body);

      // Primary call is season-wise API. If backend returns empty for this endpoint,
      // use content-wise list and keep only matching season/unassigned records.
      if (castList.isEmpty) {
        final fallback =
            await apiHelper.getApi(ApiConstant.getCastByContentId(contentId));
        final fallbackBody = jsonDecode(fallback.body);
        final allCast = _parseCastCrewListFromBody(fallbackBody);
        castList = allCast
            .where((item) =>
                item.seasonId == seasonId ||
                item.seasonId == null ||
                item.seasonId == 0)
            .toList(growable: false);
      }

      _activeCastCrewList = castList;
      _castCrewCache[_castCrewKey(contentId, seasonId)] = castList;
    } catch (e) {
      try {
        final apiHelper = ApiHelper();
        final fallback =
            await apiHelper.getApi(ApiConstant.getCastByContentId(contentId));
        final fallbackBody = jsonDecode(fallback.body);
        final allCast = _parseCastCrewListFromBody(fallbackBody);
        final castList = allCast
            .where((item) =>
                item.seasonId == seasonId ||
                item.seasonId == null ||
                item.seasonId == 0)
            .toList(growable: false);
        _activeCastCrewList = castList;
        _castCrewCache[_castCrewKey(contentId, seasonId)] = castList;
      } catch (_) {
        _castCrewError = 'Failed to load cast and crew';
        _activeCastCrewList = [];
      }
      debugPrint("Cast/Crew strict load error: $e");
    } finally {
      _isLoadingCastCrew = false;
      notifyListeners();
    }
  }

  Future<List<CastCrewItem>> fetchCastCrewListForSeason({
    required int contentId,
    required int seasonId,
  }) async {
    if (contentId <= 0 || seasonId <= 0) return <CastCrewItem>[];

    final apiHelper = ApiHelper();
    try {
      final response = await apiHelper.getApi(
        ApiConstant.getCastByContentIdAndSeasonId(
          contentId: contentId,
          seasonId: seasonId,
        ),
      );
      final body = jsonDecode(response.body);
      var castList = _parseCastCrewListFromBody(body);

      if (castList.isEmpty) {
        final fallback =
            await apiHelper.getApi(ApiConstant.getCastByContentId(contentId));
        final fallbackBody = jsonDecode(fallback.body);
        final allCast = _parseCastCrewListFromBody(fallbackBody);
        castList = allCast
            .where((item) =>
                item.seasonId == seasonId ||
                item.seasonId == null ||
                item.seasonId == 0)
            .toList(growable: false);
      }

      return castList;
    } catch (_) {
      return <CastCrewItem>[];
    }
  }

  Future<void> fetchCastCrewByContentId({
    required int contentId,
  }) async {
    if (contentId <= 0) return;

    _isLoadingCastCrew = true;
    _castCrewError = null;
    _activeCastCrewContentId = contentId;
    _activeCastCrewSeasonId = null;
    notifyListeners();

    try {
      final apiHelper = ApiHelper();
      final url = ApiConstant.getCastByContentId(contentId);
      final response = await apiHelper.getApi(url);
      final body = jsonDecode(response.body);
      final castList = _parseCastCrewListFromBody(body);

      _activeCastCrewList = castList;
      _castCrewCache[_castCrewContentOnlyKey(contentId)] = castList;
    } catch (e) {
      _castCrewError = 'Failed to load cast list';
      _activeCastCrewList = [];
      debugPrint("Cast load by contentId error: $e");
    } finally {
      _isLoadingCastCrew = false;
      notifyListeners();
    }
  }

  Future<void> fetchSeriesByMediaHouseId({
    String status = "APPROVED",
    String type = "SERIES",
    String? searchKeyword,
    String? startDate,
    String? endDate,
    int page = 0,
    bool loadMore = false,
  }) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    final mediaHouseId = mediaHouse?.id;
    if (mediaHouseId == null) {
      if (!loadMore) {
        _contentList.clear();
        _filteredContentList.clear();
        _totalItems = 0;
      }
      _hasMoreStatusItems = false;
      _hasMoreItems = false;
      isLoading = false;
      notifyListeners();
      return;
    }

    await fetchSeriesByStatusAndMediaHouseId(
      status,
      mediaHouseId,
      type: type,
      searchKeyword: searchKeyword,
      startDate: startDate,
      endDate: endDate,
      page: page,
      loadMore: loadMore,
    );
  }

  Future<void> fetchSeriesByStatusAndMediaHouseId(
    String status,
    int mediaHouseId, {
    String type = "SERIES",
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
      isLoading = true;
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
      notifyListeners();
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

    final apiHelper = ApiHelper();
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
            'Failed to fetch series. Status code: ${response.statusCode}');
      }
    } catch (error) {
      _hasMoreStatusItems = false;
      _hasMoreItems = false;
      notifyListeners();
      debugPrint("Error: $error");
      throw Exception('An error occurred while fetching series.');
    } finally {
      isLoading = false;
      _isLoadingMore = false;
      _isStatusLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchNextSeriesByStatusPage() async {
    if (_statusMediaHouseIdForPagination == null ||
        _isStatusLoadingMore ||
        !_hasMoreStatusItems) {
      return;
    }
    _isLoadingMore = true;
    _isStatusLoadingMore = true;
    notifyListeners();
    try {
      await fetchSeriesByStatusAndMediaHouseId(
        _statusValueForPagination,
        _statusMediaHouseIdForPagination!,
        type: _statusTypeForPagination,
        searchKeyword: _statusKeywordForPagination,
        startDate: _statusStartDateForPagination,
        endDate: _statusEndDateForPagination,
        page: _statusCurrentPage + 1,
        loadMore: true,
      );
    } finally {
      _isLoadingMore = false;
      _isStatusLoadingMore = false;
      notifyListeners();
    }
  }

  List<Content> _mergeContentWithoutDuplicates(
      List<Content> base, List<Content> incoming) {
    final merged = <Content>[...base];
    final seenIds = <int>{};
    for (final item in merged) {
      if (item.id != null) {
        seenIds.add(item.id!);
      }
    }
    for (final item in incoming) {
      final id = item.id;
      if (id == null || !seenIds.contains(id)) {
        merged.add(item);
        if (id != null) {
          seenIds.add(id);
        }
      }
    }
    return merged;
  }

  Future<void> uploadVideoWeb(bool isTrailer) async {
    final completer = Completer<void>();
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'video/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      if (file == null) {
        _resetVideoUploadState();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      episodeSelectedFile = file;

      final xhr = html.HttpRequest();
      final formData = html.FormData();

      formData.appendBlob('file', file, file.name);

      xhr.upload.onProgress.listen((e) {
        if (e.lengthComputable == true &&
            e.loaded != null &&
            e.total != null &&
            e.total! > 0) {
          final progress = e.loaded! / e.total!;

          movieUploadProgress = progress;
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
            _resetVideoUploadState();
            return;
          }

          print(encryptedUrl);

          movieUrlController.text = encryptedUrl;
          episodeVideoRuntime = contentImageUploadResponse.data?.duration ?? 0;
          //  movieFileName = file.name;
          movieUploadProgress = 1.0;
          _isMovieUploading = false;
          _isUploading = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete();
        } else {
          _resetVideoUploadState();
          if (!completer.isCompleted) completer.complete();
        }
      });

      xhr.onError.listen((_) {
        movieUploadProgress = 0.0;
        _isMovieUploading = false;
        _isUploading = false;

        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      });

      xhr.open('POST', ApiConstant.uploadVideoMetadata);
      final headers = await AuthService.authHeaders(includeJson: false);
      headers.forEach(xhr.setRequestHeader);
      xhr.send(formData);

      _isMovieUploading = true;

      notifyListeners();
    });
    return completer.future;
  }

  Future<void> uploadVideo(bool isTrailer) async {
    final Uri uploadUri = Uri.parse(ApiConstant.uploadVideoMetadata);

    // Reset progress at start and set uploading status

    movieUploadProgress = 0.0;
    _isMovieUploading = true;
    _isUploading = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        await uploadVideoWeb(isTrailer);
        return;
      } else {
        // Android/iOS implementation with proper progress tracking
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

        if (pickedFile != null) {
          final File file = File(pickedFile.path);
          final totalBytes = await file.length();

          print(
              "Starting upload for ${isTrailer ? 'trailer' : 'movie'}, file size: $totalBytes bytes");

          // Create a stream controller to track progress
          final StreamController<List<int>> streamController =
              StreamController<List<int>>();
          int bytesSent = 0;

          // Create the progress tracking stream
          final progressStream = file.openRead().transform(
                StreamTransformer.fromHandlers(
                  handleData: (List<int> data, EventSink<List<int>> sink) {
                    bytesSent += data.length;
                    final progress = bytesSent / totalBytes;

                    // Update progress

                    movieUploadProgress = progress;

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

          // Create the multipart request
          final request = http.MultipartRequest('POST', uploadUri);
          request.headers.addAll(
            await AuthService.authHeaders(includeJson: false),
          );

          // Add the file with progress tracking
          request.files.add(http.MultipartFile(
            'file',
            progressStream,
            totalBytes,
            filename: pickedFile.name,
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
              movieUploadProgress = 0.0;
              return;
            }

            movieUrlController.text = encryptedUrl;
            episodeVideoRuntime =
                contentImageUploadResponse.data?.duration ?? 0;
            movieUploadProgress = 1.0;

            print("Video uploaded successfully: $encryptedUrl");
          } else {
            print("Video upload failed with status: ${response.statusCode}");
            final responseBody = await response.stream.bytesToString();
            print("Error response: $responseBody");

            movieUploadProgress = 0.0;
          }
          _isMovieUploading = false;

          _isUploading = false;
          notifyListeners();
        } else {
          print("No video selected");
          // Reset progress if no video selected
          movieUploadProgress = 0.0;

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error uploading video: $e');
      // Reset progress on error
      movieUploadProgress = 0.0;

      notifyListeners();
    } finally {
      // ❌ DO NOTHING FOR WEB
      if (!kIsWeb) {
        _isMovieUploading = false;
        _isUploading = false;
        notifyListeners();
      }
    }
  }

  bool _isVideoUploadSuccessStatus(int? statusCode) {
    return statusCode == 200 || statusCode == 201 || statusCode == 202;
  }

  void _resetVideoUploadState() {
    movieUploadProgress = 0.0;
    _isMovieUploading = false;
    _isUploading = false;
    notifyListeners();
  }

  Future<void> pickEpisodeAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'aac', 'm4a'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    _isEpisodeAudioUploading = true;
    episodeAudioUploadProgress = 0.05;
    notifyListeners();

    try {
      final pickedFile = result.files.single;
      final extension = (pickedFile.extension ?? '').toLowerCase();
      if (!const {'mp3', 'wav', 'aac', 'm4a'}.contains(extension)) {
        throw Exception('Audio must be MP3, WAV, AAC, or M4A.');
      }
      if ((pickedFile.size / (1024 * 1024)) > 100) {
        throw Exception('Audio must be 100 MB or smaller.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadAudioMetadata),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );

      if (kIsWeb) {
        final bytes = pickedFile.bytes;
        if (bytes == null) throw Exception('Unable to read selected audio.');
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
          throw Exception('Unable to read selected audio.');
        }
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      episodeAudioUploadProgress = 0.45;
      notifyListeners();

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final decoded = jsonDecode(responseBody);
      final parsed = decoded is Map
          ? AudioUploadResponse.fromJson(Map<String, dynamic>.from(decoded))
          : AudioUploadResponse(message: 'Audio upload returned invalid data.');
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception(
          parsed.message?.trim().isNotEmpty == true
              ? parsed.message!.trim()
              : 'Audio upload failed with ${response.statusCode}.',
        );
      }

      final url = parsed.data?.fullUrl?.trim();
      if (url == null || url.isEmpty) {
        throw Exception('Audio upload response did not include a URL.');
      }

      episodeAudioUrlController.text = url;
      episodeAudioFileName = pickedFile.name;
      episodeAudioUploadProgress = 1.0;
    } catch (error) {
      debugPrint('Episode audio upload failed: $error');
      episodeAudioUploadProgress = 0.0;
      rethrow;
    } finally {
      _isEpisodeAudioUploading = false;
      notifyListeners();
    }
  }

  Future<void> pickEpisodeSubtitleFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt'],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    _isEpisodeSubtitleUploading = true;
    episodeSubtitleUploadProgress = 0.05;
    notifyListeners();

    try {
      final pickedFile = result.files.single;
      final extension = (pickedFile.extension ?? '').toLowerCase();
      if (!const {'srt', 'vtt'}.contains(extension)) {
        throw Exception('Subtitle must be SRT or VTT.');
      }
      if ((pickedFile.size / (1024 * 1024)) > 2) {
        throw Exception('Subtitle file must be 2 MB or smaller.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstant.uploadSubtitle),
      );
      request.headers.addAll(
        await AuthService.authHeaders(includeJson: false),
      );

      if (kIsWeb) {
        final bytes = pickedFile.bytes;
        if (bytes == null) {
          throw Exception('Unable to read selected subtitle.');
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
          throw Exception('Unable to read selected subtitle.');
        }
        request.files.add(await http.MultipartFile.fromPath('file', path));
      }

      episodeSubtitleUploadProgress = 0.45;
      notifyListeners();

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final decoded = jsonDecode(responseBody);
      if (!_isSuccessStatus(response.statusCode)) {
        throw Exception('Subtitle upload failed with ${response.statusCode}.');
      }
      final data = decoded is Map ? decoded['data'] : null;
      final url = data is Map ? data['fileUrl']?.toString().trim() : null;
      if (url == null || url.isEmpty) {
        throw Exception('Subtitle upload response did not include a URL.');
      }

      episodeSubtitleUrlController.text = url;
      episodeSubtitleFileName = pickedFile.name;
      episodeSubtitleUploadProgress = 1.0;
    } catch (error) {
      debugPrint('Episode subtitle upload failed: $error');
      episodeSubtitleUploadProgress = 0.0;
      rethrow;
    } finally {
      _isEpisodeSubtitleUploading = false;
      notifyListeners();
    }
  }

  void clearEpisodeUploadDraft() {
    movieUrlController.clear();
    episodeAudioUrlController.clear();
    episodeSubtitleUrlController.clear();
    episodeVideoRuntime = 0;
    movieUploadProgress = 0.0;
    episodeAudioUploadProgress = 0.0;
    episodeSubtitleUploadProgress = 0.0;
    _isMovieUploading = false;
    _isUploading = false;
    _isEpisodeAudioUploading = false;
    _isEpisodeSubtitleUploading = false;
    episodeAudioFileName = null;
    episodeSubtitleFileName = null;
    notifyListeners();
  }

  void clearEpisodeAudioDraft() {
    episodeAudioUrlController.clear();
    episodeAudioUploadProgress = 0.0;
    episodeAudioFileName = null;
    notifyListeners();
  }

  void clearEpisodeSubtitleDraft() {
    episodeSubtitleUrlController.clear();
    episodeSubtitleUploadProgress = 0.0;
    episodeSubtitleFileName = null;
    notifyListeners();
  }

  bool isSubmitting = false;

  Future<http.Response?> createEpisodeApiResponse(
    Map<String, dynamic> body,
    int seasonId,
  ) async {
    try {
      isSubmitting = true;
      notifyListeners();

      String apiUrl =
          '${ApiConstant.baseUrl}series/season/$seasonId/episode/add';

      debugPrint("URL => $apiUrl");
      debugPrint("BODY => ${jsonEncode(body)}");
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.postApiWithBody(apiUrl, body);

      debugPrint("STATUS => ${response.statusCode}");
      debugPrint("RESPONSE => ${response.body}");

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          episodeSelectedFile != null) {
        try {
          final decoded = jsonDecode(response.body);
          final dataMap = decoded is Map<String, dynamic>
              ? (decoded['data'] ?? decoded)
              : <String, dynamic>{};
          final epId = dataMap['id'] ?? dataMap['contentId'] ?? dataMap['episodeId'];
          if (epId != null) {
            startEpisodeMultipartUpload(
              file: episodeSelectedFile!,
              contentId: epId.toString(),
              taskId: 'episode_$epId',
            );
          }
        } catch (e) {
          debugPrint("Error parsing episode ID for multipart upload: $e");
        }
      }

      return response;
    } catch (e) {
      debugPrint("Create Episode Error: $e");
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createEpisodeApi(Map<String, dynamic> body, int seasonId) async {
    final response = await createEpisodeApiResponse(body, seasonId);
    if (response == null) return false;
    return response.statusCode == 200 || response.statusCode == 201;
  }

  bool _isSuccessStatus(int code) =>
      code == 200 || code == 201 || code == 202 || code == 204;

  Future<http.Response?> updateEpisodeApiResponse(
    Map<String, dynamic> body,
    int seasonId,
    int episodeId, {
    int? seriesId,
  }) async {
    try {
      isSubmitting = true;
      notifyListeners();

      final apiHelper = ApiHelper();
      final url = '${ApiConstant.baseUrl}series/episode/$episodeId/update';

      final response = await apiHelper.putApiWithBody(url, body);
      debugPrint('Update Episode URL => $url');
      debugPrint('Update Episode Request => $body');
      debugPrint('Update Episode Response => ${response.body}');

      if (_isSuccessStatus(response.statusCode) && episodeSelectedFile != null) {
        startEpisodeMultipartUpload(
          file: episodeSelectedFile!,
          contentId: episodeId.toString(),
          taskId: 'episode_$episodeId',
        );
      }

      return response;
    } catch (e) {
      debugPrint("Update Episode Error: $e");
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateEpisodeApi(
    Map<String, dynamic> body,
    int seasonId,
    int episodeId, {
    int? seriesId,
  }) async {
    final response = await updateEpisodeApiResponse(
      body,
      seasonId,
      episodeId,
      seriesId: seriesId,
    );
    if (response == null) return false;
    return _isSuccessStatus(response.statusCode);
  }

  Future<bool> deleteEpisodeApi(
    int seasonId,
    int episodeId, {
    int? seriesId,
  }) async {
    try {
      isSubmitting = true;
      notifyListeners();

      final apiHelper = ApiHelper();
      final url = '${ApiConstant.baseUrl}series/episode/$episodeId/delete';
      final response = await apiHelper.deleteApi(url);
      debugPrint('Delete Episode URL => $url');
      debugPrint('Delete Episode STATUS => ${response.statusCode}');
      return _isSuccessStatus(response.statusCode);
    } catch (e) {
      debugPrint("Delete Episode Error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateSeasonApi(
    Map<String, dynamic> body,
    int seasonId, {
    int? seriesId,
  }) async {
    try {
      isSubmitting = true;
      notifyListeners();

      final apiHelper = ApiHelper();
      final url = '${ApiConstant.baseUrl}series/season/$seasonId/update';
      final response = await apiHelper.putApiWithBody(url, body);
      debugPrint('Update Season URL => $url');
      debugPrint('Update Season STATUS => ${response.statusCode}');
      return _isSuccessStatus(response.statusCode);
    } catch (e) {
      debugPrint("Update Season Error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<String?> deleteSeasonApi(int seasonId, {int? seriesId}) async {
    try {
      isSubmitting = true;
      notifyListeners();

      final apiHelper = ApiHelper();
      final candidateUrls = <String>[
        if (seriesId != null)
          '${ApiConstant.baseUrl}series/$seriesId/season/$seasonId/delete',
        '${ApiConstant.baseUrl}series/season/$seasonId/delete',
      ];

      for (final url in candidateUrls) {
        final response = await apiHelper.deleteApi(url);
        debugPrint('Delete Season URL => $url');
        debugPrint('Delete Season STATUS => ${response.statusCode}');
        if (_isSuccessStatus(response.statusCode)) {
          try {
            final body = jsonDecode(response.body);
            if (body is Map && body['message'] != null) {
              return body['message'].toString();
            }
          } catch (_) {}
          return 'Season deactivated successfully';
        }
      }
      return null;
    } catch (e) {
      debugPrint("Delete Season Error: $e");
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> saveSeasonCastCrewMembers({
    required int contentId,
    required int seasonId,
    required List<Map<String, dynamic>> members,
  }) async {
    if (contentId <= 0 || seasonId <= 0) return false;
    if (members.isEmpty) return true;

    try {
      isSubmitting = true;
      notifyListeners();
      final apiHelper = ApiHelper();

      for (final member in members) {
        final payload = {
          "castId": 0,
          "contentId": contentId,
          "seasonId": seasonId,
          "name": (member["name"] ?? "").toString().trim(),
          "role": (member["role"] ?? "").toString().trim(),
          "description": (member["description"] ?? "").toString().trim(),
          "image": (member["image"] ?? "").toString().trim(),
        };

        final response =
            await apiHelper.postApiWithBody(ApiConstant.saveCast, payload);
        if (!_isSuccessStatus(response.statusCode)) {
          debugPrint("Save cast/crew failed: ${response.body}");
          return false;
        }
      }
      return true;
    } catch (e) {
      debugPrint("Save season cast/crew error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
