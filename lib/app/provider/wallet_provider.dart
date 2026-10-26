import 'package:media_house/data/models/response/movie_transaction.dart';
import 'package:flutter/foundation.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/data/models/response/production_house_wallet.dart';
import 'package:media_house/data/services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  WalletProvider({WalletService? service})
      : _service = service ?? WalletService();

  final WalletService _service;
  ProductionHouseWalletSummary? summary;
  List<WalletTransaction> transactions = const [];
  WalletTransactionFilter filter = const WalletTransactionFilter();
  bool isLoadingSummary = false;
  bool isLoadingTransactions = false;
  bool isWithdrawing = false;
  String? summaryError;
  String? transactionsError;
  String? withdrawError;
  WalletWithdrawResult? lastWithdrawResult;
  int page = 0;
  int size = 10;
  int totalElements = 0;
  int totalPages = 0;
  bool first = true;
  bool last = true;
  int? _productionHouseId;
  int _generation = 0;

  int? get productionHouseId => _productionHouseId;

  Future<void> load({bool refresh = false}) async {
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final id = mediaHouse?.id;
    if (id == null || id <= 0) {
      summaryError =
          'Production house ID is unavailable. Refresh your profile and retry.';
      transactionsError = summaryError;
      notifyListeners();
      return;
    }
    _productionHouseId = id;
    if (refresh) page = 0;
    await Future.wait([loadSummary(), loadTransactions(page: page)]);
  }

  Future<void> loadSummary() async {
    final id = _productionHouseId;
    if (id == null) return load();
    final generation = ++_generation;
    isLoadingSummary = true;
    summaryError = null;
    notifyListeners();
    try {
      final value = await _service.getSummary(id);
      if (generation == _generation) summary = value;
    } on WalletServiceException catch (error) {
      if (generation == _generation) summaryError = error.message;
    } finally {
      if (generation == _generation) {
        isLoadingSummary = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadTransactions({int page = 0, int? pageSize}) async {
    final id = _productionHouseId;
    if (id == null) return load();
    isLoadingTransactions = true;
    transactionsError = null;
    notifyListeners();
    try {
      final result = await _service.getTransactions(
        id,
        page: page,
        size: pageSize ?? size,
        filter: filter,
      );
      transactions = result.content;
      this.page = result.page;
      size = result.size > 0 ? result.size : (pageSize ?? size);
      totalElements = result.totalElements;
      totalPages = result.totalPages;
      first = result.first || this.page == 0;
      last = result.last || this.page + 1 >= totalPages;
    } on WalletServiceException catch (error) {
      transactions = const [];
      transactionsError = error.message;
    } finally {
      isLoadingTransactions = false;
      notifyListeners();
    }
  }

    List<MovieTransaction> movieTransactions = const [];
  bool isLoadingMovieTransactions = false;

  Future<void> loadMovieTransactions() async {
    final id = _productionHouseId;
    if (id == null) return;
    isLoadingMovieTransactions = true;
    notifyListeners();
    try {
      movieTransactions = await _service.getMovieTransactions(id);
    } catch (_) {
      movieTransactions = const [];
    } finally {
      isLoadingMovieTransactions = false;
      notifyListeners();
    }
  }

Future<bool> withdraw(WalletWithdrawRequest request) async {
    if (isWithdrawing) return false;
    isWithdrawing = true;
    withdrawError = null;
    lastWithdrawResult = null;
    notifyListeners();

    try {
      final response = await _service.withdrawAmount(request);
      lastWithdrawResult = response.data;
      // Authoritatively refresh wallet balance and transactions from the backend
      await load(refresh: true);
      return true;
    } on WalletServiceException catch (error) {
      withdrawError = error.message;
      return false;
    } catch (_) {
      withdrawError = 'An unexpected error occurred during withdrawal.';
      return false;
    } finally {
      isWithdrawing = false;
      notifyListeners();
    }
  }

  void clearWithdrawState() {
    withdrawError = null;
    lastWithdrawResult = null;
    notifyListeners();
  }

  Future<void> applyFilter(WalletTransactionFilter value) async {
    filter = value;
    await loadTransactions(page: 0);
  }

  Future<void> resetFilter() =>
      applyFilter(const WalletTransactionFilter());

  Future<void> changePageSize(int value) =>
      loadTransactions(page: 0, pageSize: value);

  Future<void> nextPage() =>
      last ? Future.value() : loadTransactions(page: page + 1);

  Future<void> previousPage() =>
      first ? Future.value() : loadTransactions(page: page - 1);
}
