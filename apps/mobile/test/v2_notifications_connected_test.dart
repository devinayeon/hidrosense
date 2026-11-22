import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hidrosense_mobile/data/repositories/notification_repository.dart';
import 'package:hidrosense_mobile/views/v2/connected/v2_notifications_connected.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this._items, {this.shouldFail = false});

  List<NotificationRecord> _items;
  final bool shouldFail;
  int markReadCalls = 0;

  @override
  Future<NotificationListResponse> fetchNotifications() async {
    if (shouldFail) throw Exception('Server tidak dapat dijangkau.');
    return NotificationListResponse(
      unreadCount: _items.where((i) => !i.read).length,
      items: _items,
    );
  }

  @override
  Future<void> markAllRead() async {
    markReadCalls++;
    _items = _items
        .map(
          (i) => NotificationRecord(
            id: i.id,
            category: i.category,
            title: i.title,
            subtitle: i.subtitle,
            resourceId: i.resourceId,
            read: true,
          ),
        )
        .toList();
  }
}

void main() {
  testWidgets('V2NotificationsConnectedPage loads items and marks all read', (
    tester,
  ) async {
    final repo = _FakeNotificationRepository([
      const NotificationRecord(
        id: 'nursery-ready:1',
        category: 'nursery',
        title: 'Semaian HSS 17',
        subtitle: '100 bibit siap pindah ke meja',
        resourceId: '1',
        read: false,
      ),
      const NotificationRecord(
        id: 'inventory-low:2',
        category: 'inventory',
        title: 'Stok menipis',
        subtitle: 'Benih Romaine sisa 2 pak',
        resourceId: '2',
        read: true,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: V2NotificationsConnectedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Baru'), findsOneWidget);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(find.text('Semaian HSS 17'), findsOneWidget);
    expect(find.text('Stok menipis'), findsOneWidget);

    await tester.tap(find.text('Tandai semua dibaca'));
    await tester.pumpAndSettle();

    expect(repo.markReadCalls, 1);
    expect(find.text('Baru'), findsNothing);
    expect(find.text('Sebelumnya'), findsOneWidget);
  });

  testWidgets('V2NotificationsConnectedPage shows empty state', (tester) async {
    final repo = _FakeNotificationRepository(const []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: V2NotificationsConnectedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Belum ada notifikasi'), findsOneWidget);
  });

  testWidgets('V2NotificationsConnectedPage shows error state with retry', (
    tester,
  ) async {
    final repo = _FakeNotificationRepository(const [], shouldFail: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: V2NotificationsConnectedPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal memuat notifikasi'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });
}
