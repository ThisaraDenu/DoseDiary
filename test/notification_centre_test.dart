import 'package:dose_diary/data/local/models/app_notification.dart';
import 'package:dose_diary/data/repositories/notification_repository.dart';
import 'package:dose_diary/features/settings/accessibility_screen.dart';
import 'package:dose_diary/features/home/home_dashboard_screen.dart';
import 'package:dose_diary/core/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
      'notification centre shows real notification cards and unread count',
      (tester) async {
    final now = DateTime.now();
    final notifications = [
      AppNotification(
        id: 'dose-1',
        userId: 'user-1',
        type: 'dose_overdue',
        priority: 'high',
        title: 'Medication overdue',
        body: 'Metformin 500 mg was due at 8:00 AM.',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      AppNotification(
        id: 'refill-1',
        userId: 'user-1',
        type: 'refill_low',
        priority: 'normal',
        title: 'Medication stock is low',
        body: 'Aspirin has 2 tablets remaining.',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => notifications),
        ],
        child: const MaterialApp(home: NotificationCentreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Medication overdue'), findsOneWidget);
    expect(find.text('Medication stock is low'), findsOneWidget);
    expect(find.text('1 unread'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(find.text('Medication overdue'), findsOneWidget);
    expect(find.text('Medication stock is low'), findsNothing);
  });

  testWidgets('notification centre shows its empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationsProvider.overrideWith((ref) => []),
        ],
        child: const MaterialApp(home: NotificationCentreScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text('Reminders and alerts will appear here.'), findsOneWidget);
    expect(find.text('0 unread'), findsOneWidget);
  });

  testWidgets('home notification bell opens the notification centre',
      (tester) async {
    final notification = AppNotification(
      id: 'bell-notification',
      userId: 'user-1',
      type: 'dose_due',
      priority: 'normal',
      title: 'Medication due soon',
      body: 'Take Metformin at 8:00 AM.',
      createdAt: DateTime.now(),
    );
    final router = GoRouter(
      initialLocation: RouteNames.home,
      routes: [
        GoRoute(
          path: RouteNames.home,
          builder: (_, __) => const HomeDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.notificationCentre,
          builder: (_, __) => const NotificationCentreScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayOccurrencesProvider.overrideWith((ref) => []),
          todayMedicationsProvider.overrideWith((ref) => []),
          todayAdherenceProvider.overrideWith((ref) =>
              const AdherenceSummary(taken: 0, total: 0, countable: 0)),
          lowStockProvider.overrideWith((ref) => []),
          caregiversProvider.overrideWith((ref) => []),
          patientCaregiversListProvider.overrideWith((ref) => Future.value([])),
          unreadNotificationCountProvider.overrideWith((ref) => 1),
          notificationsProvider.overrideWith((ref) => [notification]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Medication due soon'), findsOneWidget);
  });
}
