import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/session_viewmodel.dart';
import '../services/api_client.dart';

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.resourceId,
    required this.read,
  });

  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String resourceId;
  final bool read;

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: '${json['id'] ?? ''}',
      category: '${json['category'] ?? 'nursery'}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      resourceId: '${json['resource_id'] ?? ''}',
      read: json['read'] == true,
    );
  }
}

class NotificationListResponse {
  const NotificationListResponse({
    required this.unreadCount,
    required this.items,
  });

  final int unreadCount;
  final List<NotificationRecord> items;
}

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<NotificationListResponse> fetchNotifications() async {
    final response = await _api.get('notifications');
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Format respons notifikasi tidak valid.');
    }
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('Daftar notifikasi tidak valid.');
    }
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(NotificationRecord.fromJson)
        .toList();
    final unread = data['unread_count'] is int
        ? data['unread_count'] as int
        : items.where((item) => !item.read).length;
    return NotificationListResponse(unreadCount: unread, items: items);
  }

  Future<void> markAllRead() async {
    await _api.post('notifications/read-all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(apiClientProvider));
});
