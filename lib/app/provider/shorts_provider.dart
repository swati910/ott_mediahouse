import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/data/models/shorts.dart';
import 'package:media_house/data/models/response/language_group_response.dart';
import 'package:universal_html/html.dart' as html;

import '../../data/models/response/short_detail_response.dart';
import '../../data/models/response/video_upload_response.dart';
import '../core/auth/auth_service.dart';
import '../core/network/api_helper.dart';
import '../core/utils/sharepreferences.dart';
import '../core/upload/multipart_upload_persistence.dart';
import '../core/upload/s3_multipart_upload_service.dart';
import '../widget/show_toast.dart';

class ShortProvider extends ChangeNotifier {
  List<ShortModel> shorts = [];
  ShortDetailResponse? shortDetail;
  bool isLoading = false;
  String? shortsError;
  int shortsTotalItems = 0;
  int shortsTotalPages = 0;
  int shortsCurrentPage = 0;
  int _shortsRequestSerial = 0;
  bool _isUploading = false;
  bool _isMovieUploading = false;
  double movieUploadProgress = 0.0;
  Map<String, List<String>> _groupedLanguageOptions = {};
  Future<void>? _languageOptionsRequest;
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
  bool get isMovieUploading => _isMovieUploading;

  final TextEditingController movieUrlController = TextEditingController();

  html.File? partSelectedFile;
  final Map<String, S3MultipartUploadTask> _partUploadTasks = {};
  final Map<String, MultipartProgressInfo> _partUploadProgressInfo = {};

  MultipartProgressInfo? getPartProgressInfo(String taskId) =>
      _partUploadProgressInfo[taskId];

  Future<void> startPartMultipartUpload({
    required html.File file,
    required String contentId,
    required String taskId,
  }) async {
    partSelectedFile = file;

    final task = S3MultipartUploadTask(
      localTaskId: taskId,
      file: file,
      contentId: contentId,
      onProgress: (info) {
        _partUploadProgressInfo[taskId] = info;
        notifyListeners();
      },
    );

    _partUploadTasks[taskId] = task;
    await task.startOrResume();
  }

  void pausePartMultipartUpload(String taskId) {
    _partUploadTasks[taskId]?.pause();
  }

  Future<void> resumePartMultipartUpload(String taskId, {html.File? file}) async {
    final task = _partUploadTasks[taskId];
    final targetFile = file ?? partSelectedFile;
    if (task != null && targetFile != null) {
      await task.startOrResume(reselectedFile: targetFile);
    }
  }

  Future<void> retryPartMultipartUpload(String taskId) async {
    final task = _partUploadTasks[taskId];
    if (task != null && partSelectedFile != null) {
      await task.startOrResume(reselectedFile: partSelectedFile);
    }
  }

  Future<bool> abortPartMultipartUpload(String taskId, {BuildContext? context}) async {
    final task = _partUploadTasks[taskId];
    final success = (await task?.abort()) ?? true;
    if (success) {
      _partUploadTasks.remove(taskId);
      _partUploadProgressInfo.remove(taskId);
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

  Future<void> uploadVideoWeb(bool isTrailer) async {
    html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'video/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final file = uploadInput.files?.first;
      if (file == null) return;

      partSelectedFile = file;

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
          //  movieFileName = file.name;
          movieUploadProgress = 1.0;
          _isMovieUploading = false;
          notifyListeners();
        } else {
          _resetVideoUploadState();
        }
      });

      xhr.onError.listen((_) {
        movieUploadProgress = 0.0;
        _isMovieUploading = false;

        notifyListeners();
      });

      xhr.open('POST', ApiConstant.uploadVideoMetadata);
      final headers = await AuthService.authHeaders(includeJson: false);
      headers.forEach(xhr.setRequestHeader);
      xhr.send(formData);

      _isMovieUploading = true;

      notifyListeners();
    });
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
        uploadVideoWeb(isTrailer);
        return;
      } else {
        // Android/iOS implementation with proper progress tracking
        final picker = ImagePicker();
        final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

        if (pickedFile != null) {
          final io.File file = io.File(pickedFile.path);
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

  Future<void> fetchShorts({
    String keyword = '',
    int page = 0,
    int size = 10,
  }) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    final mediaHouseId = mediaHouse?.id;
    if (mediaHouseId == null) {
      shorts = [];
      shortsError = "Production house ID not found.";
      shortsTotalItems = 0;
      shortsTotalPages = 0;
      shortsCurrentPage = 0;
      notifyListeners();
      return;
    }

    final url = ApiConstant.shortsByMediaHouse(
      mediaHouseId,
      keyword: keyword,
      page: page,
      size: size,
    );
    await _fetchShortsFromUrl(url);
    if (shorts.isEmpty && (shortsError != null && shortsError!.isNotEmpty)) {
      // Fallback to legacy endpoint if v2 returns error
      final fallbackUrl = ApiConstant.shortsMaster(
        mediaHouseId,
        keyword: keyword,
        page: page,
        size: size,
      );
      await _fetchShortsFromUrl(fallbackUrl);
    }
  }

  Future<void> fetchTrendingShorts({
    String? lang,
    int page = 0,
    int size = 10,
  }) async {
    final url = ApiConstant.shortsTrending(
      lang: lang,
      page: page,
      size: size,
    );
    await _fetchShortsFromUrl(url);
  }

  Future<void> fetchShortsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 10,
  }) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    final mediaHouseId = mediaHouse?.id;
    if (mediaHouseId == null) {
      shorts = [];
      shortsError = "Production house ID not found.";
      shortsTotalItems = 0;
      shortsTotalPages = 0;
      shortsCurrentPage = 0;
      notifyListeners();
      return;
    }

    final url = ApiConstant.filterShorts(
      mediaHouseId: mediaHouseId,
      startDate: _formatDate(startDate),
      endDate: _formatDate(endDate),
      page: page,
      size: size,
    );
    await _fetchShortsFromUrl(url);
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return "$dd/$mm/$yyyy";
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
        debugPrint('Short Language Fetch Error -> $error');
      } finally {
        _isLanguageOptionsLoading = false;
        _languageOptionsRequest = null;
        notifyListeners();
      }
    }();

    return _languageOptionsRequest!;
  }

  Future<void> _fetchShortsFromUrl(String url) async {
    final requestId = ++_shortsRequestSerial;
    try {
      isLoading = true;
      shortsError = null;
      notifyListeners();

      final apiHelper = ApiHelper();
      final response = await apiHelper.getApi(url);
      final data = jsonDecode(response.body);
      final shortMasterResponse = ShortMasterResponse.fromJson(data);

      if (requestId != _shortsRequestSerial) return;

      shorts = shortMasterResponse.data?.miniSeries ?? [];
      shortsTotalItems = shortMasterResponse.data?.totalItems ?? shorts.length;
      shortsTotalPages = shortMasterResponse.data?.totalPages ?? 1;
      shortsCurrentPage = shortMasterResponse.data?.currentPage ?? 0;
    } catch (e) {
      if (requestId != _shortsRequestSerial) return;
      shorts.clear();
      shortsTotalItems = 0;
      shortsTotalPages = 0;
      shortsCurrentPage = 0;
      shortsError = "Failed to fetch shorts.";
      print("Shorts Fetch Error -> $e");
    } finally {
      if (requestId == _shortsRequestSerial) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  int? _extractShortId(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final candidates = [
      map["id"],
      map["shortId"],
      map["shortMasterId"],
    ];
    for (final value in candidates) {
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Future<ShortModel?> createShortMaster(Map<String, dynamic> body) async {
    try {
      isLoading = true;
      notifyListeners();

      final url = ApiConstant.addShortMaster;

      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.postApiWithBody(url, body);

      debugPrint("Add Short Master Request -> ${jsonEncode(body)}");
      debugPrint("Add Short Master Code -> ${response.statusCode}");
      debugPrint("Add Short Master Response -> ${response.body}");

      final Map<String, dynamic> data = jsonDecode(response.body);

      if ((response.statusCode == 200 ||
              response.statusCode == 201 ||
              response.statusCode == 202) &&
          data["success"] != false) {
        ShortModel? createdShort;
        if (data["data"] != null) {
          createdShort = ShortModel.fromJson(
            Map<String, dynamic>.from(data["data"]),
          );
          createdShort.id ??= _extractShortId(data["data"]);
        }

        await fetchShorts();

        isLoading = false;
        notifyListeners();
        return createdShort;
      } else {
        debugPrint("Add Short Master Failed -> ${data["message"]}");
      }
    } catch (e, s) {
      debugPrint("Add Short Master Exception -> $e");
      debugPrintStack(stackTrace: s);
    }

    isLoading = false;
    notifyListeners();
    return null;
  }

  Future<bool> addShortMaster(Map<String, dynamic> body) async {
    return await createShortMaster(body) != null;
  }

  Future<bool> saveShortCastCrewMembers({
    required int shortId,
    required List<Map<String, String>> members,
  }) async {
    if (shortId <= 0) {
      debugPrint("Invalid short ID for cast/crew save.");
      return false;
    }
    if (members.isEmpty) return true;

    final apiHelper = ApiHelper();
    for (final member in members) {
      final payload = {
        "castId": 0,
        "contentId": 0,
        "description": (member["description"] ?? "").trim(),
        "image": (member["image"] ?? "").trim(),
        "name": (member["name"] ?? "").trim(),
        "role": (member["role"] ?? "").trim(),
        "seasonId": 0,
        "shortId": shortId,
      };

      try {
        final response =
            await apiHelper.postApiWithBody(ApiConstant.saveCast, payload);
        debugPrint("Save Short Cast/Crew Request -> ${jsonEncode(payload)}");
        debugPrint("Save Short Cast/Crew Code -> ${response.statusCode}");
        debugPrint("Save Short Cast/Crew Response -> ${response.body}");

        if (response.statusCode != 200 &&
            response.statusCode != 201 &&
            response.statusCode != 202) {
          return false;
        }

        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["success"] == false) {
          return false;
        }
      } catch (e, s) {
        debugPrint("Save Short Cast/Crew Exception -> $e");
        debugPrintStack(stackTrace: s);
        return false;
      }
    }

    return true;
  }

  // ==========================================
  // FETCH CAST BY SHORT ID
  // ==========================================
  List<Map<String, dynamic>> _shortCastList = [];
  bool _isLoadingShortCast = false;
  List<Map<String, dynamic>> get shortCastList => _shortCastList;
  bool get isLoadingShortCast => _isLoadingShortCast;

  Future<void> fetchCastByShortId(int shortId) async {
    if (shortId <= 0) {
      _shortCastList = [];
      notifyListeners();
      return;
    }
    _isLoadingShortCast = true;
    notifyListeners();
    final apiHelper = ApiHelper();
    try {
      final apiUrl = ApiConstant.getCastByShortId(shortId);
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        final list = decoded["data"] ?? decoded["cast"] ?? decoded;
        if (list is List) {
          _shortCastList = list
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        } else {
          _shortCastList = [];
        }
      } else {
        _shortCastList = [];
      }
    } catch (e) {
      debugPrint("Error fetching cast by shortId: $e");
      _shortCastList = [];
    } finally {
      _isLoadingShortCast = false;
      notifyListeners();
    }
  }

  Future<bool> deleteShortMaster({
    required int shortId,
    void Function(String message)? onMessage,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final url = "${ApiConstant.deleteShortMaster}/$shortId";

      debugPrint("DELETE SHORT → $url");

      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.deleteApi(url);

      debugPrint("Delete Response Code → ${response.statusCode}");
      debugPrint("Delete Response Body → ${response.body}");

      final Map<String, dynamic> data = jsonDecode(response.body);

      /// ✅ SUCCESS
      if (data["success"] == true) {
        onMessage?.call(data["message"] ?? "Short deleted successfully");

        /// 🔄 Refresh list safely
        await fetchShorts();

        isLoading = false;
        notifyListeners();
        return true;
      }

      /// ❌ FAILURE (API responded but success=false)
      onMessage?.call(
        data["message"] ?? "Failed to delete short",
      );
    } catch (e, s) {
      debugPrint("Delete Short Exception → $e");
      debugPrintStack(stackTrace: s);

      onMessage?.call("Something went wrong while deleting short");
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  /*Future<bool> updateShortMaster({
    required int shortId,
    required Map<String, dynamic> body,
    void Function(String message)? onMessage,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final url = Uri.parse(
        "${ApiConstant.updateShortMaster}/$shortId",
      );

      debugPrint("UPDATE SHORT → $url");
      debugPrint("BODY → ${jsonEncode(body)}");

      final response = await http.put(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      debugPrint("Response Code → ${response.statusCode}");
      debugPrint("Response Body → ${response.body}");

      final Map<String, dynamic> data = jsonDecode(response.body);

      /// ✅ SUCCESS
      if (data["success"] == true) {
        onMessage?.call(data["message"] ?? "Short updated successfully");

        /// Update local model if backend returns updated short
        if (data["data"] != null) {
          shortDetail = ShortDetailResponse.fromJson(data["data"]);
        }

        /// 🔄 Refresh list
        await fetchShorts();

        isLoading = false;
        notifyListeners();
        return true;
      }

      /// ❌ API returned success=false
      onMessage?.call(
        data["message"] ?? "Failed to update short",
      );
    } catch (e, s) {
      debugPrint("Update Short Exception → $e");
      debugPrintStack(stackTrace: s);

      onMessage?.call("Something went wrong while updating short");
    }

    isLoading = false;
    notifyListeners();
    return false;
  }*/

  /// Optimistic remove
  void removeShortLocally(int shortId) {
    shorts.removeWhere((s) => s.id == shortId);
    notifyListeners();
  }

  /// Undo restore
  void restoreShort(ShortModel short, int index) {
    shorts.insert(index, short);
    notifyListeners();
  }

  bool isSubmitting = false;

  Future<bool> createShortPart(Map<String, dynamic> body) async {
    try {
      isSubmitting = true;
      notifyListeners();

      String apiUrl = ApiConstant.createShortPart;
      debugPrint("Create Short Part URL -> $apiUrl");
      debugPrint("Create Short Part Body -> ${jsonEncode(body)}");
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.postApiWithBody(apiUrl, body);
      debugPrint("Create Short Part Code -> ${response.statusCode}");
      debugPrint("Create Short Part Response -> ${response.body}");
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 202) {
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded["success"] == false) {
        return false;
      }

      if (partSelectedFile != null) {
        try {
          final dataMap = decoded is Map<String, dynamic>
              ? (decoded['data'] ?? decoded)
              : <String, dynamic>{};
          final partId = dataMap['id'] ?? dataMap['contentId'] ?? dataMap['partId'];
          if (partId != null) {
            startPartMultipartUpload(
              file: partSelectedFile!,
              contentId: partId.toString(),
              taskId: 'part_$partId',
            );
          }
        } catch (e) {
          debugPrint("Error parsing part ID for multipart upload: $e");
        }
      }

      return true;
    } catch (e) {
      debugPrint("Create Short Part Error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  bool isDetailLoading = false;
  String? detailError;

  Future<void> fetchShortDetail({
    required int shortId,
    required int userId,
  }) async {
    try {
      isDetailLoading = true;
      detailError = null;
      notifyListeners();

      var url = ApiConstant.shortsDetails(shortId, userId);
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.getApi(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final res = ShortDetailResponse.fromJson(decoded);
        shortDetail = res;
      } else {
        detailError = "Failed to load short details";
      }
    } catch (e) {
      detailError = e.toString();
    } finally {
      isDetailLoading = false;
      notifyListeners();
    }
  }

  bool isPartDeleting = false;
  Future<bool> deleteShortPart({
    required String partId,
  }) async {
    try {
      isPartDeleting = true;
      notifyListeners();

      final url = "${ApiConstant.deletePart(partId)}";
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.deleteApi(url);
      debugPrint(response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['success'] == true) {
          return true;
        } else {
          debugPrint("❌ Delete part failed: ${decoded['message']}");
          return false;
        }
      } else {
        debugPrint("❌ Delete part HTTP error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ Delete part exception: $e");
      return false;
    } finally {
      isPartDeleting = false;
      notifyListeners();
    }
  }

  Future<bool> updateShortPart(Map<String, dynamic> body, String partId) async {
    try {
      isSubmitting = true;
      notifyListeners();

      String url = "${ApiConstant.baseUrl}api/short-parts/$partId";
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.putApiWithBody(url, body);
      debugPrint(jsonEncode(body));
      debugPrint(response.body);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Update part error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateShortMaster(
      Map<String, dynamic> body, String shortId) async {
    try {
      isSubmitting = true;
      notifyListeners();
      String url = "${ApiConstant.baseUrl}api/shortsMaster/$shortId";
      ApiHelper apiHelper = ApiHelper();
      var response = await apiHelper.putApiWithBody(url, body);
      debugPrint(jsonEncode(body));
      debugPrint(response.body);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ Update part error: $e");
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
