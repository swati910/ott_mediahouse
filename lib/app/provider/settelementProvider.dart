import 'package:flutter/foundation.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/app/core/storage/portal_cache_service.dart';
import 'package:media_house/app/core/storage/storage_keys.dart';
import 'package:media_house/app/core/storage/storage_service.dart';
import 'package:media_house/data/models/response/media_house_settlement.dart';
import 'package:media_house/data/models/response/weekly_settlement_report.dart';
import 'package:media_house/data/models/response/transaction_settlement_audit_response.dart';
import 'package:media_house/data/services/settlement_service.dart';

class SettelementProvider extends ChangeNotifier {
  final SettlementService _service;
  SettelementProvider({SettlementService? service})
      : _service = service ?? SettlementService();

  List<MediaHouseSettlement> _settlements = const [];
  List<MediaHouseSettlement> get settlements => _settlements;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  int _page = 0;
  int get page => _page;
  int _pageSize = 10;
  int get pageSize => _pageSize;
  int _totalElements = 0;
  int get totalElements => _totalElements;
  int _totalPages = 0;
  int get totalPages => _totalPages;
  bool _first = true;
  bool get first => _first;
  bool _last = true;
  bool get last => _last;
  int? _mediaHouseId;
  int _requestGeneration = 0;
  String? _userId;
  bool _showingCachedData = false;
  bool get showingCachedData => _showingCachedData;
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  // Transaction Settlement Audit state
  TransactionSettlementAuditResponse? _selectedTransactionAudit;
  TransactionSettlementAuditResponse? get selectedTransactionAudit =>
      _selectedTransactionAudit;
  bool _isLoadingAudit = false;
  bool get isLoadingAudit => _isLoadingAudit;
  String? _auditErrorMessage;
  String? get auditErrorMessage => _auditErrorMessage;

  // Weekly Settlement Report state
  WeeklySettlementReportResponse? _weeklyReport;
  WeeklySettlementReportResponse? get weeklyReport => _weeklyReport;
  bool _isLoadingWeeklyReport = false;
  bool get isLoadingWeeklyReport => _isLoadingWeeklyReport;
  String? _weeklyReportError;
  String? get weeklyReportError => _weeklyReportError;

  Future<void> fetchForCurrentMediaHouse({int? page, int? size}) async {
    final user = await LocalSharePreferences().getUser();
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final id = mediaHouse?.id;
    final userId = user?.id;
    if (id == null || id <= 0 || userId == null || userId <= 0) {
      _requestGeneration++;
      _settlements = const [];
      _errorMessage =
          'Media house ID is unavailable. Please refresh your profile.';
      _isLoading = false;
      notifyListeners();
      return;
    }
    _userId = userId.toString();
    _mediaHouseId = id;
    await fetchPage(page ?? _page, size: size ?? _pageSize);
  }

  Future<void> fetchPage(int requestedPage, {int? size}) async {
    final id = _mediaHouseId;
    if (id == null || id <= 0) {
      return fetchForCurrentMediaHouse(page: requestedPage, size: size);
    }
    final requestedSize = size ?? _pageSize;
    final generation = ++_requestGeneration;
    if (_isLoading || _isLoadingMore) return;
    final append = requestedPage > 0;
    if (append && (_last || requestedPage <= _page)) return;
    if (append) {
      _isLoadingMore = true;
    } else {
      _isLoading = true;
      _settlements = const [];
    }
    _errorMessage = null;
    if (!append) {
      await _loadCache(id, requestedPage, requestedSize);
    }
    notifyListeners();
    try {
      final response = await _service.getMediaHouseSettlements(
        id,
        page: requestedPage,
        size: requestedSize,
      );
      if (generation != _requestGeneration) return;
      final data = response.data;
      if (append) {
        final seen = _settlements
            .map((item) => item.settlementId)
            .whereType<String>()
            .toSet();
        _settlements.clear();
        _settlements = [
          ..._settlements,
          ...data.content.where((item) =>
              item.settlementId == null || seen.add(item.settlementId!)),
        ];
      } else {
        _settlements.clear();
        _settlements = data.content;
      }
      _page = data.number;
      _pageSize = data.size > 0 ? data.size : requestedSize;
      _totalElements = data.totalElements;
      _totalPages = data.totalPages;
      _first = data.first;
      _last = data.last || data.content.length < requestedSize;
      _showingCachedData = false;
      _lastUpdated = DateTime.now().toUtc();
      await _writeCache(id, data, requestedPage, requestedSize);
    } on SettlementServiceException catch (error) {
      if (generation != _requestGeneration) return;
      if (!append && !_showingCachedData) _settlements = const [];
      _errorMessage = error.message;
      if (!_showingCachedData) {
        _page = requestedPage;
        _pageSize = requestedSize;
        _totalElements = 0;
        _totalPages = 0;
        _first = requestedPage == 0;
        _last = true;
      }
    } finally {
      if (generation == _requestGeneration) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<TransactionSettlementAuditResponse?> fetchTransactionSettlementAudit(
      dynamic transactionId) async {
    _isLoadingAudit = true;
    _auditErrorMessage = null;
    _selectedTransactionAudit = null;
    notifyListeners();
    try {
      final res = await _service.getTransactionSettlementReport(transactionId);
      _selectedTransactionAudit = res;
      _isLoadingAudit = false;
      notifyListeners();
      return res;
    } catch (e) {
      _auditErrorMessage = e.toString();
      _isLoadingAudit = false;
      notifyListeners();
      return null;
    }
  }

  Future<WeeklySettlementReportResponse?> fetchWeeklySettlementReportById(
      dynamic settlementId) async {
    _isLoadingWeeklyReport = true;
    _weeklyReportError = null;
    _weeklyReport = null;
    notifyListeners();
    try {
      final res = await _service.getWeeklySettlementReportById(settlementId);
      _weeklyReport = res;
      _isLoadingWeeklyReport = false;
      notifyListeners();
      return res;
    } catch (e) {
      _weeklyReportError = e.toString();
      _isLoadingWeeklyReport = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> changePageSize(int size) => fetchPage(0, size: size);
  Future<void> retry() => fetchPage(_page, size: _pageSize);
  Future<void> refresh() => fetchForCurrentMediaHouse(page: 0, size: _pageSize);
  Future<void> loadMore() => fetchPage(_page + 1, size: _pageSize);

  String? _cacheKey(int mediaHouseId, int page, int size) {
    final userId = _userId;
    if (userId == null) return null;
    return PortalCacheService.scopedKey(
      userId: userId,
      mediaHouseId: mediaHouseId.toString(),
      dataType: 'settlements',
      query: {'page': page, 'size': size},
    );
  }

  Future<void> _loadCache(int mediaHouseId, int page, int size) async {
    if (!StorageService.instance.cacheAvailable) return;
    final key = _cacheKey(mediaHouseId, page, size);
    final userId = _userId;
    if (key == null || userId == null) return;
    final entry = await StorageService.instance.portalCache.read(
      boxName: HiveBoxes.settlementCache,
      key: key,
      userId: userId,
      mediaHouseId: mediaHouseId.toString(),
    );
    if (entry == null) return;
    try {
      final data = SettlementPageData.fromJson(entry.payload);
      _settlements = data.content;
      _page = data.number;
      _pageSize = data.size;
      _totalElements = data.totalElements;
      _totalPages = data.totalPages;
      _first = data.first;
      _last = data.last;
      _showingCachedData = true;
      _lastUpdated = entry.createdAt;
    } catch (_) {
      await StorageService.instance.portalCache
          .delete(HiveBoxes.settlementCache, key);
    }
  }

  Future<void> _writeCache(
    int mediaHouseId,
    SettlementPageData data,
    int page,
    int size,
  ) async {
    if (!StorageService.instance.cacheAvailable) return;
    final key = _cacheKey(mediaHouseId, page, size);
    final userId = _userId;
    if (key == null || userId == null) return;
    await StorageService.instance.portalCache.write(
      boxName: HiveBoxes.settlementCache,
      key: key,
      userId: userId,
      mediaHouseId: mediaHouseId.toString(),
      payload: data.toJson(),
      ttl: CacheTtl.settlements,
    );
  }
}
