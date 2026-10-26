import 'dart:convert';
import 'dart:io';

import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/network/api_helper.dart';
import 'package:media_house/data/models/response/media_house_settlement.dart';
import 'package:media_house/data/models/response/weekly_settlement_report.dart';
import 'package:media_house/data/models/response/transaction_settlement_audit_response.dart';

class SettlementServiceException implements Exception {
  final String message;
  final int? statusCode;
  const SettlementServiceException(this.message, {this.statusCode});
}

class SettlementService {
  final ApiHelper _api;
  SettlementService({ApiHelper? api}) : _api = api ?? ApiHelper();

  Future<MediaHouseSettlementResponse> getMediaHouseSettlements(
    int mediaHouseId, {
    int page = 0,
    int size = 10,
  }) async {
    if (mediaHouseId <= 0) {
      throw const SettlementServiceException('Media house ID is unavailable.');
    }
    if (page < 0 || size < 1 || size > 100) {
      throw const SettlementServiceException(
        'Invalid media house or pagination parameters.',
        statusCode: 400,
      );
    }

    try {
      final response = await _api.getApi(ApiConstant.mediaHouseSettlements(
        mediaHouseId,
        page: page,
        size: size,
      ));
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      if (response.statusCode != 200) {
        throw SettlementServiceException(
          _errorMessage(response.statusCode, body?['message']?.toString()),
          statusCode: response.statusCode,
        );
      }
      final parsed = MediaHouseSettlementResponse.fromJson(body ?? const {});
      if (!parsed.success) {
        throw SettlementServiceException(
          parsed.message.isEmpty
              ? 'Unable to fetch media house settlements.'
              : parsed.message,
          statusCode: parsed.statusCode,
        );
      }
      return parsed;
    } on SettlementServiceException {
      rethrow;
    } on SocketException {
      throw const SettlementServiceException(
          'Unable to connect. Please check your connection and retry.');
    } on FormatException {
      throw const SettlementServiceException(
          'The settlement service returned an invalid response.');
    } catch (_) {
      throw const SettlementServiceException(
          'Unable to fetch media house settlements.');
    }
  }

  Future<WeeklySettlementReportResponse> getWeeklySettlementReport(
    int mediaHouseId,
    String settlementBatchReference,
  ) async {
    if (mediaHouseId <= 0) {
      throw const SettlementServiceException('Media house ID is unavailable.');
    }
    if (settlementBatchReference.trim().isEmpty) {
      throw const SettlementServiceException(
          'Settlement batch reference is unavailable.');
    }
    try {
      final response = await _api.getApi(
        ApiConstant.mediaHouseWeeklySettlementReport(
          mediaHouseId,
          settlementBatchReference: settlementBatchReference,
        ),
      );
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode != 200) {
        throw SettlementServiceException(
          _reportErrorMessage(
              response.statusCode, body?['message']?.toString()),
          statusCode: response.statusCode,
        );
      }
      final parsed = WeeklySettlementReportResponse.fromJson(body ?? const {});
      if (!parsed.success) {
        throw SettlementServiceException(
          parsed.message.isEmpty
              ? 'Unable to fetch the settlement report.'
              : parsed.message,
          statusCode: parsed.statusCode,
        );
      }
      return parsed;
    } on SettlementServiceException {
      rethrow;
    } on SocketException {
      throw const SettlementServiceException(
          'Unable to connect. Please check your connection and retry.');
    } on FormatException {
      throw const SettlementServiceException(
          'The settlement report service returned an invalid response.');
    } catch (_) {
      throw const SettlementServiceException(
          'Unable to fetch the settlement report.');
    }
  }

  Future<WeeklySettlementReportResponse> getWeeklySettlementReportById(
    dynamic settlementId,
  ) async {
    if (settlementId == null || settlementId.toString().trim().isEmpty) {
      throw const SettlementServiceException('Settlement ID is unavailable.');
    }
    try {
      final response = await _api.getApi(
        ApiConstant.weeklySettlementReportById(settlementId),
      );
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode != 200) {
        throw SettlementServiceException(
          _reportErrorMessage(
              response.statusCode, body?['message']?.toString()),
          statusCode: response.statusCode,
        );
      }
      final parsed = WeeklySettlementReportResponse.fromJson(body ?? const {});
      if (!parsed.success) {
        throw SettlementServiceException(
          parsed.message.isEmpty
              ? 'Unable to fetch the settlement report.'
              : parsed.message,
          statusCode: parsed.statusCode,
        );
      }
      return parsed;
    } on SettlementServiceException {
      rethrow;
    } on SocketException {
      throw const SettlementServiceException(
          'Unable to connect. Please check your connection and retry.');
    } on FormatException {
      throw const SettlementServiceException(
          'The settlement report service returned an invalid response.');
    } catch (_) {
      throw const SettlementServiceException(
          'Unable to fetch the settlement report.');
    }
  }

  Future<TransactionSettlementAuditResponse> getTransactionSettlementReport(
    dynamic transactionId,
  ) async {
    if (transactionId == null || transactionId.toString().trim().isEmpty) {
      throw const SettlementServiceException('Transaction ID is unavailable.');
    }
    try {
      final response = await _api.getApi(
        ApiConstant.transactionSettlementReport(transactionId),
      );
      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}
      if (response.statusCode != 200) {
        throw SettlementServiceException(
          _errorMessage(response.statusCode, body?['message']?.toString()),
          statusCode: response.statusCode,
        );
      }
      final parsed =
          TransactionSettlementAuditResponse.fromJson(body ?? const {});
      return parsed;
    } on SettlementServiceException {
      rethrow;
    } on SocketException {
      throw const SettlementServiceException(
          'Unable to connect. Please check your connection and retry.');
    } on FormatException {
      throw const SettlementServiceException(
          'The transaction audit service returned an invalid response.');
    } catch (_) {
      throw const SettlementServiceException(
          'Unable to fetch transaction settlement reconciliation report.');
    }
  }

  String _reportErrorMessage(int status, String? backendMessage) {
    if (backendMessage?.trim().isNotEmpty == true) return backendMessage!.trim();
    switch (status) {
      case 403:
        return 'You are not allowed to access this settlement report.';
      case 404:
        return 'Settlement report not found.';
      case 500:
        return 'The settlement report service is unavailable.';
      default:
        return 'Unable to fetch the settlement report.';
    }
  }

  String _errorMessage(int status, String? backendMessage) {
    switch (status) {
      case 400:
        return 'Invalid media house or pagination parameters.';
      case 403:
        return 'You are not allowed to access these settlements.';
      case 404:
        return 'Media house not found.';
      case 500:
        return 'Unable to fetch media house settlements.';
      default:
        return backendMessage?.trim().isNotEmpty == true
            ? backendMessage!.trim()
            : 'Unable to fetch media house settlements.';
    }
  }
}
