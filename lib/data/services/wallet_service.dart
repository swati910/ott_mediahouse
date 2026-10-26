import 'package:media_house/data/models/response/movie_transaction.dart';
import 'dart:convert';
import 'dart:io';

import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/network/api_helper.dart';
import 'package:media_house/data/models/response/production_house_wallet.dart';

class WalletServiceException implements Exception {
  const WalletServiceException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class WalletService {
  WalletService({ApiHelper? api}) : _api = api ?? ApiHelper();
  final ApiHelper _api;

  Future<ProductionHouseWalletSummary> getSummary(int productionHouseId) async {
    try {
      final body = await _get(
        ApiConstant.productionHouseWalletSummary(productionHouseId),
        fallback: 'Unable to fetch wallet summary.',
      );
      final data = _mapPayload(
        body['data'] ?? body,
        const ['summary', 'walletSummary', 'wallet'],
      );
      if (data == null) {
        throw const WalletServiceException(
            'The wallet service returned an invalid summary.');
      }
      return ProductionHouseWalletSummary.fromJson(data);
    } catch (_) {
      // Fallback: try wallet history if dedicated summary endpoint is not present
      try {
        final historyBody = await _get(
          ApiConstant.walletHistory(productionHouseId),
          fallback: 'Unable to fetch wallet summary.',
        );
        final data = historyBody['data'] is Map
            ? Map<String, dynamic>.from(historyBody['data'])
            : null;
        if (data != null) {
          return ProductionHouseWalletSummary.fromJson(data);
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<WalletTransactionPage> getTransactions(
    int productionHouseId, {
    required int page,
    required int size,
    required WalletTransactionFilter filter,
  }) async {
    try {
      final body = await _get(
        ApiConstant.productionHouseWalletTransactions(
          productionHouseId,
          page: page,
          size: size,
          search: filter.search,
          transactionType: filter.transactionType,
          status: filter.status,
          entryType: filter.entryType,
          fromDate: filter.fromDate,
          toDate: filter.toDate,
          minAmount: filter.minAmount,
          maxAmount: filter.maxAmount,
        ),
        fallback: 'Unable to fetch wallet transactions.',
      );
      final data = _mapPayload(
        body['data'] ?? body,
        const ['transactions', 'transactionPage', 'page'],
      );
      if (data == null) {
        throw const WalletServiceException(
            'The wallet service returned an invalid transaction list.');
      }
      return WalletTransactionPage.fromJson(data);
    } catch (_) {
      // Fallback to history endpoint if available
      try {
        final historyBody = await _get(
          ApiConstant.walletHistory(productionHouseId),
          fallback: 'Unable to fetch wallet transactions.',
        );
        final data = historyBody['data'] is Map
            ? Map<String, dynamic>.from(historyBody['data'])
            : null;
        if (data != null) {
          return WalletTransactionPage.fromJson(data);
        }
      } catch (_) {}
      rethrow;
    }
  }

    Future<List<MovieTransaction>> getMovieTransactions(int mediaHouseId) async {
    try {
      final body = await _get(
        ApiConstant.movieTransactionsByMediaHouse(mediaHouseId),
        fallback: 'Unable to fetch movie transactions.',
      );
      final response = MovieTransactionResponse.fromJson(body);
      return response.data;
    } catch (_) {
      return const [];
    }
  }

Future<WalletWithdrawResponse> withdrawAmount(
      WalletWithdrawRequest request) async {
    try {
      final response = await _api.postApiWithBody(
        ApiConstant.withdrawWalletAmount,
        request.toJson(),
      );

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      final statusCode = response.statusCode;
      final isSuccess = statusCode == 200 || statusCode == 201;

      if (!isSuccess || body?['success'] == false) {
        final errorMsg = _message(
          statusCode,
          body?['message']?.toString() ?? body?['error']?.toString(),
          'Withdrawal request failed. Please verify your balance and try again.',
        );
        throw WalletServiceException(errorMsg, statusCode: statusCode);
      }

      return WalletWithdrawResponse.fromJson(body ?? {'success': true});
    } on WalletServiceException {
      rethrow;
    } on SocketException {
      throw const WalletServiceException(
          'Network error. Please check your internet connection and retry.');
    } on FormatException {
      throw const WalletServiceException(
          'Received an invalid response from the withdrawal server.');
    } catch (e) {
      throw WalletServiceException(
        e is WalletServiceException
            ? e.message
            : 'Unable to process withdrawal. Please try again later.',
      );
    }
  }

  Map<String, dynamic>? _mapPayload(dynamic raw, List<String> nestedKeys) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    for (final key in nestedKeys) {
      final nested = map[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return map;
  }

  Future<Map<String, dynamic>> _get(String url,
      {required String fallback}) async {
    try {
      final response = await _api.getApi(url);
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode != 200 || body?['success'] == false) {
        throw WalletServiceException(
          _message(response.statusCode, body?['message']?.toString(), fallback),
          statusCode: response.statusCode,
        );
      }
      return body ?? const {};
    } on WalletServiceException {
      rethrow;
    } on SocketException {
      throw const WalletServiceException(
          'Unable to connect. Check your network and retry.');
    } on FormatException {
      throw const WalletServiceException(
          'The wallet service returned an invalid response.');
    } catch (_) {
      throw WalletServiceException(fallback);
    }
  }

  String _message(int status, String? backend, String fallback) {
    if (backend?.trim().isNotEmpty == true) return backend!.trim();
    return switch (status) {
      400 => 'Invalid withdrawal request or insufficient wallet balance.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You are not authorized to perform withdrawals on this wallet.',
      404 => 'Wallet or bank account details not found.',
      409 => 'A withdrawal request is already in progress.',
      422 => 'Invalid withdrawal amount or unsupported bank details.',
      429 => 'Too many requests. Please wait a moment before trying again.',
      500 => 'Server error while processing withdrawal. Please try again later.',
      _ => fallback,
    };
  }
}
