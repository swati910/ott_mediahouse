import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:media_house/app/core/constant/api_constant.dart';
import 'package:media_house/app/core/network/api_helper.dart';
import 'package:media_house/app/core/utils/sharepreferences.dart';
import 'package:media_house/data/models/response/image_upload_response.dart';
import 'package:media_house/data/services/mock_notification_service.dart';
import 'package:media_house/domain/entities/notification_model.dart';
import 'package:media_house/domain/entities/notification_settings_model.dart';
import 'package:media_house/domain/entities/user_model.dart';

class NotificationSettingsProvider extends ChangeNotifier {
  NotificationSettingsProvider({
    MockNotificationService? service,
  }) : _service = service ?? MockNotificationService();

  final MockNotificationService _service;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  final TextEditingController emailSubjectController = TextEditingController();
  final TextEditingController historySearchController = TextEditingController();

  NotificationSettingsModel _settings = const NotificationSettingsModel();
  NotificationSettingsModel get settings => _settings;

  List<UserModel> _users = [];
  List<UserModel> get users => List.unmodifiable(_users);

  List<NotificationModel> _notifications = [];
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  _NotificationAnalytics? _analytics;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSending = false;
  bool get isSending => _isSending;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _attachmentName;
  String? get attachmentName => _attachmentName;

  String? _attachmentUrl;
  String? get attachmentUrl => _attachmentUrl;

  int _attachmentSize = 0;
  String _attachmentType = '';

  bool _isAttachmentUploading = false;
  bool get isAttachmentUploading => _isAttachmentUploading;

  NotificationHistoryFilter? _historyFilter;
  NotificationHistoryFilter? get historyFilter => _historyFilter;

  NotificationType? _typeFilter;
  NotificationType? get typeFilter => _typeFilter;

  NotificationDeliveryStatus? _statusFilter;
  NotificationDeliveryStatus? get statusFilter => _statusFilter;

  DateTimeRange? _customDateRange;
  DateTimeRange? get customDateRange => _customDateRange;

  String _sortDirection = 'desc';
  String get sortDirection => _sortDirection;

  int _page = 0;
  static const int _pageSize = 10;

  int get totalSent => _analytics?.totalSent ?? _notifications.length;
  int get failedCount =>
      _analytics?.failedCount ??
      _notifications
          .where((item) =>
              item.deliveryStatus == NotificationDeliveryStatus.failed)
          .length;
  int get deliveredCount =>
      _analytics?.deliveredCount ??
      _notifications
          .where((item) =>
              item.deliveryStatus == NotificationDeliveryStatus.delivered)
          .length;
  double get successRate {
    if (_analytics != null) {
      return (_analytics!.successRate / 100).clamp(0, 1).toDouble();
    }
    return _notifications.isEmpty ? 0 : deliveredCount / _notifications.length;
  }

  List<UserModel> get selectedUsers {
    final ids = _settings.selectedUserIds.toSet();
    return _users.where((user) => ids.contains(user.id)).toList();
  }

  bool get hasActiveFilters =>
      _historyFilter != null ||
      _typeFilter != null ||
      _statusFilter != null ||
      _sortDirection != 'desc';

  Future<void> initialize() async {
    if (_users.isNotEmpty || _isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _users = await _service.fetchUsers();
      _notifications = await _fetchMediaHouseNotifications(page: 0);
      await _fetchAnalytics();
      _page = 0;
    } catch (error) {
      _errorMessage = 'Unable to load settings data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _page = 0;
    _hasMore = true;
    _errorMessage = null;
    try {
      _users = await _service.fetchUsers();
      _notifications = await _fetchMediaHouseNotifications(page: _page);
      await _fetchAnalytics();
    } catch (error) {
      _errorMessage = 'Unable to refresh notifications. Please try again.';
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final nextPage = _page + 1;
      final nextItems = await _fetchMediaHouseNotifications(page: nextPage);
      _notifications = [..._notifications, ...nextItems];
      _page = nextPage;
    } catch (error) {
      _errorMessage = 'Unable to load more notifications. Please try again.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void updateRecipientType(NotificationRecipientType type) {
    _settings = _settings.copyWith(recipientType: type);
    notifyListeners();
  }

  void toggleSelectedUser(UserModel user) {
    final ids = List<int>.from(_settings.selectedUserIds);
    ids.contains(user.id) ? ids.remove(user.id) : ids.add(user.id);
    _settings = _settings.copyWith(
      recipientType: NotificationRecipientType.selectedUsers,
      selectedUserIds: ids,
    );
    notifyListeners();
  }

  void removeSelectedUser(int userId) {
    final ids = List<int>.from(_settings.selectedUserIds)..remove(userId);
    _settings = _settings.copyWith(selectedUserIds: ids);
    notifyListeners();
  }

  void updatePriority(NotificationPriority priority) {
    _settings = _settings.copyWith(priority: priority);
    notifyListeners();
  }

  void updateChannel(NotificationType type, bool value) {
    _settings = _settings.copyWith(
      sendPush: type == NotificationType.push ? value : null,
      sendEmail: type == NotificationType.email ? value : null,
      sendSms: type == NotificationType.sms ? value : null,
    );
    notifyListeners();
  }

  Future<void> pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'doc',
        'docx',
        'jpg',
        'jpeg',
        'png',
        'xls',
        'xlsx',
        'txt',
      ],
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    _attachmentName = pickedFile.name;
    _attachmentUrl = null;
    _attachmentSize = pickedFile.size;
    _attachmentType = pickedFile.extension ?? '';
    _isAttachmentUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _attachmentUrl = await _uploadAttachment(pickedFile);
      _errorMessage = null;
    } catch (error) {
      _attachmentName = null;
      _attachmentUrl = null;
      _attachmentSize = 0;
      _attachmentType = '';
      _errorMessage = 'Unable to upload the attachment. Please try again.';
    } finally {
      _isAttachmentUploading = false;
      notifyListeners();
    }
  }

  void clearAttachment() {
    _attachmentName = null;
    _attachmentUrl = null;
    _attachmentSize = 0;
    _attachmentType = '';
    notifyListeners();
  }

  String? validateComposer() {
    if (titleController.text.trim().isEmpty) {
      return 'Notification title is required.';
    }
    if (messageController.text.trim().isEmpty) {
      return 'Message description is required.';
    }
    if (emailSubjectController.text.trim().isEmpty && _settings.sendEmail) {
      return 'Email subject is required when email is enabled.';
    }
    if (!_settings.sendPush && !_settings.sendEmail && !_settings.sendSms) {
      return 'Choose at least one delivery channel.';
    }
    if (_settings.recipientType == NotificationRecipientType.selectedUsers &&
        _settings.selectedUserIds.isEmpty) {
      return 'Select at least one user.';
    }
    if (_isAttachmentUploading) {
      return 'Please wait for the attachment upload to finish.';
    }
    if (_attachmentName != null &&
        (_attachmentUrl == null || _attachmentUrl!.trim().isEmpty)) {
      return 'Attachment upload failed. Remove it or upload again.';
    }
    return null;
  }

  Future<String?> sendNow({DateTime? scheduledAt}) async {
    if (scheduledAt != null) {
      return scheduleNotification(scheduledAt);
    }

    final validationMessage = validateComposer();
    if (validationMessage != null) return validationMessage;

    _isSending = true;
    notifyListeners();
    try {
      await _sendNotificationToApi(
        title: titleController.text.trim(),
        message: messageController.text.trim(),
        emailSubject: emailSubjectController.text.trim(),
        settings: _settings,
        endpoint: ApiConstant.sendNotification,
      );
      _page = 0;
      _notifications = await _fetchMediaHouseNotifications(page: _page);
      await _fetchAnalytics();
      titleController.clear();
      messageController.clear();
      emailSubjectController.clear();
      clearAttachment();
      _errorMessage = null;
      return null;
    } catch (error) {
      return 'Unable to send notification: $error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> scheduleNotification(DateTime scheduledAt) async {
    final validationMessage = validateComposer();
    if (validationMessage != null) return validationMessage;
    if (!scheduledAt.isAfter(DateTime.now())) {
      return 'Choose a future date and time for scheduling.';
    }

    _isSending = true;
    notifyListeners();
    try {
      await _sendNotificationToApi(
        title: titleController.text.trim(),
        message: messageController.text.trim(),
        emailSubject: emailSubjectController.text.trim(),
        settings: _settings,
        scheduledAt: scheduledAt,
        endpoint: ApiConstant.scheduleNotification,
      );
      _page = 0;
      _notifications = await _fetchMediaHouseNotifications(page: _page);
      await _fetchAnalytics();
      titleController.clear();
      messageController.clear();
      emailSubjectController.clear();
      clearAttachment();
      _errorMessage = null;
      return null;
    } catch (error) {
      return 'Unable to schedule notification: $error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> resend(NotificationModel notification) async {
    _isSending = true;
    notifyListeners();
    try {
      final apiMessage = await _resendNotificationToApi(notification.id);
      _page = 0;
      _notifications = await _fetchMediaHouseNotifications(page: _page);
      await _fetchAnalytics();
      _errorMessage = null;
      return apiMessage;
    } catch (error) {
      return 'Unable to resend notification: $error';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<String?> _resendNotificationToApi(int notificationId) async {
    final response = await ApiHelper().postApi(
      ApiConstant.resendNotification(notificationId),
    );

    final statusCode = response.statusCode as int;
    if (statusCode == 200 || statusCode == 201 || statusCode == 202) {
      return _readApiSuccess(response.body);
    }
    throw _readApiError(response.body);
  }

  Future<List<NotificationModel>> _fetchMediaHouseNotifications({
    required int page,
  }) async {
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final mediaHouseId = mediaHouse?.id ?? 0;
    if (mediaHouseId == 0) return [];

    final dateRange = _resolveHistoryDateRange();
    final response = await ApiHelper().getApi(
      ApiConstant.notificationsByMediaHouse(
        mediaHouseId: mediaHouseId,
        page: page,
        size: _pageSize,
        sortDir: _sortDirection,
        startDate: _formatDateParam(dateRange?.start),
        endDate: _formatDateParam(dateRange?.end),
      ),
    );

    print(ApiConstant.notificationsByMediaHouse(
      mediaHouseId: mediaHouseId,
      page: page,
      size: _pageSize,
      sortDir: _sortDirection,
      startDate: _formatDateParam(dateRange?.start),
      endDate: _formatDateParam(dateRange?.end),
    ));
    final statusCode = response.statusCode as int;
    if (statusCode != 200) {
      throw _readApiError(response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) return [];
    final content = data['content'];
    if (content is! List) return [];

    final items = content
        .whereType<Map<String, dynamic>>()
        .map(_notificationFromApi)
        .where(_matchesLocalFilters)
        .toList();

    final hasNext = data['hasNext'];
    _hasMore = hasNext is bool ? hasNext : items.length == _pageSize;
    return items;
  }

  DateTimeRange? _resolveHistoryDateRange() {
    final now = DateTime.now();
    switch (_historyFilter) {
      case NotificationHistoryFilter.today:
        return DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case NotificationHistoryFilter.thisWeek:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
      case NotificationHistoryFilter.thisMonth:
        return DateTimeRange(
          start: DateTime(now.year, now.month),
          end: now,
        );
      case NotificationHistoryFilter.custom:
        return _customDateRange;
      case null:
        return null;
    }
  }

  String? _formatDateParam(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _matchesLocalFilters(NotificationModel notification) {
    if (_typeFilter != null && notification.notificationType != _typeFilter) {
      return false;
    }
    if (_statusFilter != null && notification.deliveryStatus != _statusFilter) {
      return false;
    }
    final query = historySearchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      return notification.title.toLowerCase().contains(query) ||
          notification.message.toLowerCase().contains(query) ||
          notification.sentBy.toLowerCase().contains(query);
    }
    return true;
  }

  Future<void> _fetchAnalytics({String timeRange = 'TODAY'}) async {
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final mediaHouseId = mediaHouse?.id ?? 0;
    if (mediaHouseId == 0) return;

    final response = await ApiHelper().getApi(
      ApiConstant.notificationAnalytics(
        mediaHouseId: mediaHouseId,
        timeRange: timeRange,
      ),
    );

    final statusCode = response.statusCode as int;
    if (statusCode != 200) {
      throw _readApiError(response.body);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        _analytics = _NotificationAnalytics.fromJson(data);
      }
    }
  }

  Future<void> _sendNotificationToApi({
    required String title,
    required String message,
    required String emailSubject,
    required NotificationSettingsModel settings,
    required String endpoint,
    DateTime? scheduledAt,
  }) async {
    final response = await ApiHelper().postApiWithBody(
      endpoint,
      await _buildNotificationPayload(
        title: title,
        message: message,
        emailSubject: emailSubject,
        settings: settings,
        scheduledAt: scheduledAt,
      ),
    );

    final statusCode = response.statusCode as int;
    if (statusCode == 200 || statusCode == 201 || statusCode == 202) {
      return;
    }
    throw _readApiError(response.body);
  }

  Future<Map<String, dynamic>> _buildNotificationPayload({
    required String title,
    required String message,
    required String emailSubject,
    required NotificationSettingsModel settings,
    DateTime? scheduledAt,
  }) async {
    final mediaHouse = await LocalSharePreferences().getMediaHouse();
    final now = DateTime.now();
    final deliveryTime = scheduledAt ?? now;
    final recurringEndDate = deliveryTime.add(const Duration(days: 1));

    return {
      'attachmentUrl': _attachmentUrl ?? '',
      'attachments': _attachmentName == null
          ? []
          : [
              {
                'fileName': _attachmentName,
                'fileSize': _attachmentSize,
                'fileType': _attachmentType,
                'fileUrl': _attachmentUrl ?? '',
              },
            ],
      'cronExpression': '',
      'emailSubject': emailSubject,
      'isRecurring': false,
      'mediaHouseId': mediaHouse?.id ?? 0,
      'messageDescription': message,
      'notificationTitle': title,
      'priority': settings.priority.apiValue,
      'recipientGroupId': 0,
      'recipientType': settings.recipientType.apiValue,
      'recipientUserIds':
          settings.recipientType == NotificationRecipientType.selectedUsers
              ? settings.selectedUserIds
              : <int>[],
      'recurringEndDate': recurringEndDate.toUtc().toIso8601String(),
      'scheduledTime': deliveryTime.toUtc().toIso8601String(),
      'sendEmail': settings.sendEmail,
      'sendNow': scheduledAt == null,
      'sendPushNotification': settings.sendPush,
      'sendSms': settings.sendSms,
    };
  }

  Future<String> _uploadAttachment(PlatformFile pickedFile) async {
    final request =
        http.MultipartRequest('POST', Uri.parse(ApiConstant.uploadDocument));

    if (kIsWeb) {
      final bytes = pickedFile.bytes;
      if (bytes == null) {
        throw 'Unable to read selected file bytes.';
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
        throw 'Unable to read selected file path.';
      }
      request.files.add(await http.MultipartFile.fromPath('file', path));
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _readApiError(responseBody);
    }

    final fileUrl = _readUploadedFileUrl(responseBody);
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      throw 'Upload response did not include a file URL.';
    }
    return fileUrl.trim();
  }

  String? _readUploadedFileUrl(String body) {
    final decoded = jsonDecode(body);
    if (decoded is String) return decoded;
    if (decoded is Map<String, dynamic>) {
      final parsed = ImageUploadResponse.fromJson(decoded);
      final modelUrl = parsed.data?.fileUrl;
      if (modelUrl != null && modelUrl.trim().isNotEmpty) {
        return modelUrl;
      }
      final data = decoded['data'];
      if (data is Map<String, dynamic>) {
        return (data['fileUrl'] ?? data['url'] ?? data['fullUrl'])?.toString();
      }
      return (decoded['fileUrl'] ?? decoded['url'] ?? decoded['fullUrl'])
          ?.toString();
    }
    return null;
  }

  String _readApiError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['error'] ?? decoded['details'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      if (body.trim().isNotEmpty) return body;
    }
    return 'Notification API request failed.';
  }

  String? _readApiSuccess(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> deleteNotification(int id) async {
    await _service.deleteNotification(id);
    _notifications = _notifications.where((item) => item.id != id).toList();
    notifyListeners();
  }

  Future<void> applyFilters({
    NotificationHistoryFilter? historyFilter,
    NotificationType? typeFilter,
    NotificationDeliveryStatus? statusFilter,
    DateTimeRange? customDateRange,
    String? sortDirection,
    bool clear = false,
  }) async {
    if (clear) {
      _historyFilter = null;
      _typeFilter = null;
      _statusFilter = null;
      _customDateRange = null;
      _sortDirection = 'desc';
    } else {
      _historyFilter = historyFilter;
      _typeFilter = typeFilter;
      _statusFilter = statusFilter;
      _customDateRange = customDateRange;
      _sortDirection = sortDirection ?? _sortDirection;
    }
    await refresh();
  }

  Future<void> searchHistory(String query) async {
    await refresh();
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    emailSubjectController.dispose();
    historySearchController.dispose();
    super.dispose();
  }
}

extension _NotificationRecipientTypeApiValue on NotificationRecipientType {
  String get apiValue {
    switch (this) {
      case NotificationRecipientType.adminOnly:
        return 'ADMIN_ONLY';
      case NotificationRecipientType.allUsers:
        return 'ALL_USERS';
      case NotificationRecipientType.selectedUsers:
        return 'SELECTED_USERS';
      case NotificationRecipientType.productionTeam:
        return 'PRODUCTION_TEAM';
      case NotificationRecipientType.directors:
        return 'DIRECTORS';
      case NotificationRecipientType.actors:
        return 'ACTORS';
      case NotificationRecipientType.mediaPartners:
        return 'MEDIA_PARTNERS';
    }
  }
}

extension _NotificationPriorityApiValue on NotificationPriority {
  String get apiValue {
    switch (this) {
      case NotificationPriority.low:
        return 'LOW';
      case NotificationPriority.medium:
        return 'MEDIUM';
      case NotificationPriority.high:
        return 'HIGH';
      case NotificationPriority.urgent:
        return 'URGENT';
    }
  }
}

NotificationModel _notificationFromApi(Map<String, dynamic> json) {
  final type = _notificationTypeFromApi(json['notificationType']);
  return NotificationModel(
    id: _readIntValue(json['id']),
    title: json['notificationTitle']?.toString() ?? '',
    message: json['messageDescription']?.toString() ?? '',
    sentBy: json['sentBy']?.toString() ?? 'Production Admin',
    sentAt: _readDateValue(json['sentDateTime']) ??
        _readDateValue(json['createdDate']) ??
        DateTime.now(),
    recipientType: _recipientTypeFromApi(json['recipientType']),
    deliveryStatus: _deliveryStatusFromApi(json['deliveryStatus']),
    notificationType: type,
    priority: _priorityFromApi(json['priority']),
    recipientCount: _readIntValue(json['totalRecipients']),
  );
}

NotificationRecipientType _recipientTypeFromApi(dynamic value) {
  switch (value?.toString().toUpperCase()) {
    case 'ALL_USERS':
      return NotificationRecipientType.allUsers;
    case 'SELECTED_USERS':
      return NotificationRecipientType.selectedUsers;
    case 'PRODUCTION_TEAM':
      return NotificationRecipientType.productionTeam;
    case 'DIRECTORS':
      return NotificationRecipientType.directors;
    case 'ACTORS':
      return NotificationRecipientType.actors;
    case 'MEDIA_PARTNERS':
      return NotificationRecipientType.mediaPartners;
    case 'ADMIN_ONLY':
    default:
      return NotificationRecipientType.adminOnly;
  }
}

NotificationPriority _priorityFromApi(dynamic value) {
  switch (value?.toString().toUpperCase()) {
    case 'LOW':
      return NotificationPriority.low;
    case 'HIGH':
      return NotificationPriority.high;
    case 'URGENT':
      return NotificationPriority.urgent;
    case 'MEDIUM':
    default:
      return NotificationPriority.medium;
  }
}

NotificationType _notificationTypeFromApi(dynamic value) {
  switch (value?.toString().toUpperCase()) {
    case 'EMAIL':
      return NotificationType.email;
    case 'SMS':
      return NotificationType.sms;
    case 'PUSH':
    case 'IN_APP':
    default:
      return NotificationType.push;
  }
}

NotificationDeliveryStatus _deliveryStatusFromApi(dynamic value) {
  switch (value?.toString().toUpperCase()) {
    case 'FAILED':
    case 'PARTIAL_FAILED':
      return NotificationDeliveryStatus.failed;
    case 'PENDING':
      return NotificationDeliveryStatus.scheduled;
    case 'SENT':
    case 'DELIVERED':
    case 'OPENED':
    case 'READ':
    default:
      return NotificationDeliveryStatus.delivered;
  }
}

DateTime? _readDateValue(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

int _readIntValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class _NotificationAnalytics {
  const _NotificationAnalytics({
    required this.totalSent,
    required this.failedCount,
    required this.deliveredCount,
    required this.successRate,
  });

  final int totalSent;
  final int failedCount;
  final int deliveredCount;
  final double successRate;

  factory _NotificationAnalytics.fromJson(Map<String, dynamic> json) {
    return _NotificationAnalytics(
      totalSent: _readInt(json['totalNotificationsSent']),
      failedCount: _readInt(json['totalNotificationsFailed']),
      deliveredCount: _readInt(json['totalNotificationsDelivered']),
      successRate: _readDouble(json['successRate']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
