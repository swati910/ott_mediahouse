import 'package:media_house/domain/entities/notification_model.dart';
import 'package:media_house/domain/entities/notification_settings_model.dart';
import 'package:media_house/domain/entities/user_model.dart';

class MockNotificationService {
  final List<UserModel> _users = const [
    UserModel(
      id: 1,
      name: 'Aarav Mehta',
      email: 'aarav@filmytell.com',
      role: 'Admin',
      department: 'Operations',
      isOnline: true,
    ),
    UserModel(
      id: 2,
      name: 'Nisha Rao',
      email: 'nisha@filmytell.com',
      role: 'Director',
      department: 'Creative',
      isOnline: true,
    ),
    UserModel(
      id: 3,
      name: 'Kabir Sethi',
      email: 'kabir@filmytell.com',
      role: 'Actor',
      department: 'Talent',
    ),
    UserModel(
      id: 4,
      name: 'Meera Iyer',
      email: 'meera@filmytell.com',
      role: 'Producer',
      department: 'Production Team',
      isOnline: true,
    ),
    UserModel(
      id: 5,
      name: 'Rohan Kapoor',
      email: 'rohan@partner.in',
      role: 'Media Partner',
      department: 'Distribution',
    ),
    UserModel(
      id: 6,
      name: 'Sana Khan',
      email: 'sana@filmytell.com',
      role: 'Actor',
      department: 'Talent',
    ),
  ];

  final List<NotificationModel> _notifications = List.generate(18, (index) {
    final priority = NotificationPriority.values[index % 4];
    final type = NotificationType.values[index % 3];
    final status = NotificationDeliveryStatus.values[index % 4];
    final recipient = NotificationRecipientType.values[index % 7];
    return NotificationModel(
      id: index + 1,
      title: [
        'Premiere Window Updated',
        'Agreement Approval Required',
        'Revenue Report Published',
        'New Content Quality Check',
      ][index % 4],
      message:
          'OTT operations update for release planning, partner communication, and production workflow alignment.',
      sentBy: index.isEven ? 'Production Admin' : 'Content Operations',
      sentAt: DateTime.now().subtract(Duration(hours: index * 7)),
      recipientType: recipient,
      deliveryStatus: status,
      notificationType: type,
      priority: priority,
      recipientCount: 12 + (index * 8),
    );
  });

  Future<List<UserModel>> fetchUsers() async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    return List<UserModel>.from(_users);
  }

  Future<List<NotificationModel>> fetchNotifications({
    int page = 1,
    int limit = 8,
    String query = '',
    NotificationHistoryFilter? filter,
    NotificationType? type,
    NotificationDeliveryStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    Iterable<NotificationModel> result = _notifications;

    if (query.trim().isNotEmpty) {
      final lowerQuery = query.trim().toLowerCase();
      result = result.where(
        (item) =>
            item.title.toLowerCase().contains(lowerQuery) ||
            item.message.toLowerCase().contains(lowerQuery) ||
            item.sentBy.toLowerCase().contains(lowerQuery),
      );
    }

    if (filter != null) {
      final now = DateTime.now();
      result = result.where((item) {
        switch (filter) {
          case NotificationHistoryFilter.today:
            return item.sentAt.year == now.year &&
                item.sentAt.month == now.month &&
                item.sentAt.day == now.day;
          case NotificationHistoryFilter.thisWeek:
            return now.difference(item.sentAt).inDays <= 7;
          case NotificationHistoryFilter.thisMonth:
            return item.sentAt.year == now.year &&
                item.sentAt.month == now.month;
          case NotificationHistoryFilter.custom:
            if (startDate == null || endDate == null) {
              return item.sentAt.year == now.year &&
                  item.sentAt.month == now.month;
            }
            final start =
                DateTime(startDate.year, startDate.month, startDate.day);
            final end =
                DateTime(endDate.year, endDate.month, endDate.day, 23, 59);
            return !item.sentAt.isBefore(start) && !item.sentAt.isAfter(end);
        }
      });
    }

    if (type != null) {
      result = result.where((item) => item.notificationType == type);
    }
    if (status != null) {
      result = result.where((item) => item.deliveryStatus == status);
    }

    final start = (page - 1) * limit;
    final items = result.toList();
    if (start >= items.length) return [];
    final end = (start + limit) > items.length ? items.length : start + limit;
    return items.sublist(start, end);
  }

  Future<NotificationModel> sendNotification({
    required String title,
    required String message,
    required String emailSubject,
    required NotificationSettingsModel settings,
    String? attachmentName,
    DateTime? scheduledAt,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 850));
    final type = settings.sendPush
        ? NotificationType.push
        : settings.sendEmail
            ? NotificationType.email
            : NotificationType.sms;
    final model = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      message: message,
      sentBy: 'Production Admin',
      sentAt: scheduledAt ?? DateTime.now(),
      recipientType: settings.recipientType,
      deliveryStatus: scheduledAt == null
          ? NotificationDeliveryStatus.delivered
          : NotificationDeliveryStatus.scheduled,
      notificationType: type,
      priority: settings.priority,
      recipientCount:
          settings.recipientType == NotificationRecipientType.selectedUsers
              ? settings.selectedUserIds.length
              : 128,
    );
    _notifications.insert(0, model);
    return model;
  }

  Future<void> deleteNotification(int id) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _notifications.removeWhere((item) => item.id == id);
  }
}
