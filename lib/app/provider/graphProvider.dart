import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:media_house/data/models/response/TopRatedMovie.dart';
import 'package:media_house/data/models/response/reportAndDataResponse.dart';
import 'package:media_house/data/models/response/topRevenueMovie.dart';

import '../core/constant/api_constant.dart';
import '../core/network/api_helper.dart';
import '../core/utils/sharepreferences.dart';
import '../widget/show_toast.dart';

class GraphProvider extends ChangeNotifier {
  DateTimeRange? selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );
  DateTime get today => DateTime.now();
  DateTime? startDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? endDate =
      DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
  String activeButton = 'Month';

  bool isYear = false;
  bool isMonth = true;
  bool isWeek = false;

  String _selectedContentType = "ALL";
  String _countryFilter = "";
  String _stateFilter = "";
  String _districtFilter = "";
  String _talukaFilter = "";
  String _cityFilter = "";

  String get selectedContentType => _selectedContentType;
  String get countryFilter => _countryFilter;
  String get stateFilter => _stateFilter;
  String get districtFilter => _districtFilter;
  String get talukaFilter => _talukaFilter;
  String get cityFilter => _cityFilter;

  final List<String> _countryOptions = [];
  List<String> get countryOptions => _countryOptions;

  final List<String> _stateOptions = [];
  List<String> get stateOptions => _stateOptions;

  bool _isLoadingCountries = false;
  bool get isLoadingCountries => _isLoadingCountries;

  bool _isLoadingStates = false;
  bool get isLoadingStates => _isLoadingStates;

  List<ContentWithRevenue> chartData = [];
  List<ContentWithRating> chartData1 = [];
  List<Map<String, dynamic>> graphData = [];

  List<ReportAndDataObject> _reportAndDataList = [];
  List<ReportAndDataObject> get reportAndDataList => _reportAndDataList;
  bool _isLoadingReportData = false;
  bool get isLoadingReportData => _isLoadingReportData;

  void _clearTopMoviesGraphState() {
    chartData.clear();
    chartData1.clear();
    graphData.clear();
  }

  void setContentTypeFilter(String value) {
    _selectedContentType = value;
    notifyListeners();
  }

  void setCountryFilter(String value) {
    _countryFilter = value;
    notifyListeners();
  }

  void setStateFilter(String value) {
    _stateFilter = value;
    notifyListeners();
  }

  void setDistrictFilter(String value) {
    _districtFilter = value;
    notifyListeners();
  }

  void setTalukaFilter(String value) {
    _talukaFilter = value;
    notifyListeners();
  }

  setCityFilter(String value) {
    _cityFilter = value;
    notifyListeners();
  }

  Future<void> fetchCountriesIfNeeded() async {
    if (_countryOptions.isNotEmpty || _isLoadingCountries) return;
    await fetchCountries();
  }

  Future<void> fetchCountries() async {
    _isLoadingCountries = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/positions'),
      );
      if (response.statusCode != 200) return;

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (jsonBody['data'] as List<dynamic>? ?? const []);
      _countryOptions
        ..clear()
        ..addAll(
          data
              .map((item) =>
                  (item as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((name) => name.trim().isNotEmpty),
        );
      _countryOptions
          .sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (_) {
      // Silent fallback; user can still type city/district/taluka.
    } finally {
      _isLoadingCountries = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatesByCountry(String country) async {
    _isLoadingStates = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('https://countriesnow.space/api/v0.1/countries/states'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'country': country}),
      );
      if (response.statusCode != 200) return;

      final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
      final data = jsonBody['data'] as Map<String, dynamic>?;
      final states = (data?['states'] as List<dynamic>? ?? const []);
      _stateOptions
        ..clear()
        ..addAll(
          states
              .map((item) =>
                  (item as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((name) => name.trim().isNotEmpty),
        );
      _stateOptions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (_) {
      _stateOptions.clear();
    } finally {
      _isLoadingStates = false;
      notifyListeners();
    }
  }

  Future<void> selectCountryAndLoadStates(String country) async {
    _countryFilter = country;
    _stateFilter = '';
    _stateOptions.clear();
    notifyListeners();
    if (country.trim().isEmpty) return;
    await fetchStatesByCountry(country.trim());
  }

  void clearStateOptions() {
    _stateOptions.clear();
    _isLoadingStates = false;
    notifyListeners();
  }

  void clearTopMoviesFilters() {
    _selectedContentType = "ALL";
    _countryFilter = "";
    _stateFilter = "";
    _districtFilter = "";
    _talukaFilter = "";
    _cityFilter = "";
    notifyListeners();
  }

  Future<void> applyTopMoviesFilters(context, bool isRevenue) async {
    if (activeButton == "Month") {
      await _fetchByTimeRangeIndex(context, 1, isRevenue);
      return;
    }
    if (activeButton == "Year") {
      await _fetchByTimeRangeIndex(context, 2, isRevenue);
      return;
    }
    await _fetchByTimeRangeIndex(context, 0, isRevenue);
  }

  Future<void> _fetchByTimeRangeIndex(
      context, int selectedTimeRange, bool isRevenue) {
    return isRevenue
        ? fetchTopPerformingMovieGraph(context, selectedTimeRange)
        : fetchTopRatedMovieGraph(context, selectedTimeRange);
  }

  String? _normalizeFilter(String value, {bool allAsNull = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (allAsNull && trimmed.toUpperCase() == "ALL") return null;
    return trimmed;
  }

  falseAllFilter() {
    isYear = false;
    isMonth = false;
    isWeek = false;
  }

  Future<void> fetchTopPerformingMovieGraph(
      context, int selectedTimeRange) async {
    if (startDate == null || endDate == null) return;

    final start = DateFormat('yyyy-MM-dd').format(startDate!);
    final end = DateFormat('yyyy-MM-dd').format(endDate!);
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();

    if (selectedTimeRange == 0) {
      isWeek = true;
      isMonth = false;
      isYear = false;
    } else if (selectedTimeRange == 1) {
      isWeek = false;
      isMonth = true;
      isYear = false;
    } else {
      isWeek = false;
      isMonth = false;
      isYear = true;
    }

    final apiUrl = ApiConstant.topRevenueContentGraph(
      mediaHouse!.id,
      start,
      end,
      isYear,
      isMonth,
      isWeek,
      contentType: _normalizeFilter(_selectedContentType, allAsNull: true),
      country: _normalizeFilter(_countryFilter),
      state: _normalizeFilter(_stateFilter),
      district: _normalizeFilter(_districtFilter),
      taluka: _normalizeFilter(_talukaFilter),
      city: _normalizeFilter(_cityFilter),
    );

    final apiHelper = ApiHelper();

    try {
      _clearTopMoviesGraphState();
      notifyListeners();
      debugPrint(apiUrl);
      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Request failed with status ${response.statusCode}');
      }
      final responseBody = json.decode(response.body) as Map<String, dynamic>;
      final topRevenueMovie = TopRevenueMovie.fromJson(responseBody);
      debugPrint(response.body);
      if (topRevenueMovie.success == true) {
        final items = topRevenueMovie.data?.contentWithRevenue ?? [];
        chartData = List<ContentWithRevenue>.from(items);
        for (final data in chartData) {
          graphData.add({
            "label": data.name,
            "value": data.mediaHouseNetRevenue ?? data.totalRevenue ?? 0.0,
          });
        }
      } else {
        CustomToast.show(
          context,
          topRevenueMovie.message.toString(),
          isSuccess: topRevenueMovie.success ?? false,
        );
      }
      notifyListeners();
    } catch (error) {
      _clearTopMoviesGraphState();
      notifyListeners();
      debugPrint("Error occurred while fetching graph data: $error");
    }
  }

  Future<void> fetchTopRatedMovieGraph(context, int selectedTimeRange) async {
    if (startDate == null || endDate == null) return;

    final start = DateFormat('yyyy-MM-dd').format(startDate!);
    final end = DateFormat('yyyy-MM-dd').format(endDate!);
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();

    if (selectedTimeRange == 0) {
      isWeek = true;
      isMonth = false;
      isYear = false;
    } else if (selectedTimeRange == 1) {
      isWeek = false;
      isMonth = true;
      isYear = false;
    } else {
      isWeek = false;
      isMonth = false;
      isYear = true;
    }

    final apiUrl = ApiConstant.topRatedContentGraph(
      mediaHouse!.id,
      start,
      end,
      isYear,
      isMonth,
      isWeek,
      contentType: _normalizeFilter(_selectedContentType, allAsNull: true),
      country: _normalizeFilter(_countryFilter),
      state: _normalizeFilter(_stateFilter),
      district: _normalizeFilter(_districtFilter),
      taluka: _normalizeFilter(_talukaFilter),
      city: _normalizeFilter(_cityFilter),
    );

    final apiHelper = ApiHelper();

    try {
      _clearTopMoviesGraphState();
      notifyListeners();

      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Request failed with status ${response.statusCode}');
      }
      final responseBody = json.decode(response.body) as Map<String, dynamic>;
      final topRatedMovie = TopRatedMovie.fromJson(responseBody);

      if (topRatedMovie.success == true) {
        final items = topRatedMovie.data?.contentWithRatings ?? [];
        chartData1 = List<ContentWithRating>.from(items);
        for (final data in chartData1) {
          graphData.add({
            "label": data.name,
            "value": data.avgRating,
          });
        }
      } else {
        CustomToast.show(
          context,
          topRatedMovie.message.toString(),
          isSuccess: topRatedMovie.success ?? false,
        );
      }
      notifyListeners();
    } catch (error) {
      _clearTopMoviesGraphState();
      notifyListeners();
      debugPrint("Error occurred while fetching graph data: $error");
    }
  }

  void setDateRange(
      String label, int days, BuildContext context, bool isRevenue) {
    if (label == "Custom Dates") {
      pickDateRange(context, isRevenue);
    } else {
      activeButton = label;
      endDate = today;
      startDate = endDate!.subtract(Duration(days: days));
      selectedDateRange = DateTimeRange(start: startDate!, end: endDate!);

      if (label == "Week") {
        _fetchByTimeRangeIndex(context, 0, isRevenue);
      } else if (label == "Month") {
        _fetchByTimeRangeIndex(context, 1, isRevenue);
      } else if (label == "Year") {
        _fetchByTimeRangeIndex(context, 2, isRevenue);
      } else {
        _fetchByTimeRangeIndex(context, 0, isRevenue);
      }

      notifyListeners();
    }
  }

  Future<void> pickDateRange(BuildContext context, bool isRevenue) async {
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            width: 560,
            child: DateRangePickerDialog(
              firstDate: DateTime(2020),
              lastDate: today,
              initialDateRange:
                  activeButton == 'Custom Dates' ? selectedDateRange : null,
              helpText: 'Select Custom Date Range',
              confirmText: 'Apply',
              cancelText: 'Cancel',
            ),
          ),
        );
      },
    );

    if (picked != null) {
      selectedDateRange = picked;
      activeButton = 'Custom Dates';
      startDate = picked.start;
      endDate = picked.end;
      _fetchByTimeRangeIndex(context, 0, isRevenue);
      notifyListeners();
    }
  }

  Future<void> getReportAndData(
    BuildContext context, {
    String? contentType,
    String? country,
    String? state,
    String? district,
    String? taluka,
    String? city,
    DateTime? startDate,
    DateTime? endDate,
    String? ageGroup,
    String? gender,
  }) async {
    final localSharePreferences = LocalSharePreferences();
    final mediaHouse = await localSharePreferences.getMediaHouse();
    if (mediaHouse?.id == null) {
      _reportAndDataList.clear();
      notifyListeners();
      return;
    }

    final String? start =
        startDate == null ? null : DateFormat('yyyy-MM-dd').format(startDate);
    final String? end =
        endDate == null ? null : DateFormat('yyyy-MM-dd').format(endDate);

    final apiUrl = ApiConstant.reportAndData(
      mediaHouse!.id,
      contentType: _normalizeFilter(contentType ?? "", allAsNull: true),
      country: _normalizeFilter(country ?? ""),
      state: _normalizeFilter(state ?? ""),
      district: _normalizeFilter(district ?? ""),
      taluka: _normalizeFilter(taluka ?? ""),
      city: _normalizeFilter(city ?? ""),
      startDate: start,
      endDate: end,
      ageGroup: _normalizeFilter(ageGroup ?? "", allAsNull: true),
      gender: _normalizeFilter(gender ?? "", allAsNull: true),
    );
    final apiHelper = ApiHelper();
    debugPrint(apiUrl);
    try {
      _isLoadingReportData = true;
      _reportAndDataList.clear();
      notifyListeners();

      final response = await apiHelper.getApi(apiUrl);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _reportAndDataList = [];
        CustomToast.show(
          context,
          "Failed to load reports (status ${response.statusCode}).",
          isSuccess: false,
        );
        return;
      }

      final responseBody = json.decode(response.body) as Map<String, dynamic>;
      ReportAndDataResponse reportAndDataResponse =
          ReportAndDataResponse.fromJson(responseBody);

      if (reportAndDataResponse.success == true) {
        final items = reportAndDataResponse.data?.contents ?? [];
        _reportAndDataList = List<ReportAndDataObject>.from(items);
      } else {
        CustomToast.show(
          context,
          reportAndDataResponse.message.toString(),
          isSuccess: reportAndDataResponse.success ?? false,
        );
      }
      notifyListeners();
    } catch (error) {
      _reportAndDataList.clear();
      debugPrint("Error occurred while fetching graph data: $error");
      CustomToast.show(
        context,
        "Unable to load report data right now.",
        isSuccess: false,
      );
    } finally {
      _isLoadingReportData = false;
      notifyListeners();
    }
  }
}
