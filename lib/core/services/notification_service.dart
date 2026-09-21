import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const LinuxInitializationSettings linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open notification');

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> showBudgetAlert({
    required int id,
    required String categoryName,
    required double percentage,
    required String spentFormatted,
    required String limitFormatted,
  }) async {
    try {
      final isExceeded = percentage >= 1.0;
      final title = isExceeded
          ? '🚨 Budget Alert: $categoryName Exceeded!'
          : '⚠️ Budget Warning: $categoryName';

      final body = isExceeded
          ? 'You have spent $spentFormatted of your $limitFormatted budget (${(percentage * 100).toInt()}%).'
          : 'You have reached ${(percentage * 100).toInt()}% ($spentFormatted / $limitFormatted) of your $categoryName budget.';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'budget_alerts',
        'Budget Alerts',
        channelDescription: 'Alerts when your spending reaches budget limits',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(id, title, body, details);
    } catch (e) {
      debugPrint('Error showing budget alert: $e');
    }
  }

  Future<void> showRecurringBillReminder({
    required int id,
    required String note,
    required String amountFormatted,
    required DateTime date,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'bill_reminders',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming bills and recurring payments',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        id,
        '⏰ Upcoming Bill: $note',
        'Your recurring payment of $amountFormatted is scheduled for today.',
        details,
      );
    } catch (e) {
      debugPrint('Error showing bill reminder: $e');
    }
  }

  Future<void> showStreakAtRiskReminder({
    required int currentStreak,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'streak_reminders',
        'Streak Reminders',
        channelDescription: 'Reminders to log daily expenses and maintain your streak',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      final title = currentStreak > 0
          ? '🔥 Keep your $currentStreak-day streak alive!'
          : '🔥 Log today\'s spending!';
      final body = currentStreak > 0
          ? 'Don\'t lose your $currentStreak-day streak — log today\'s spending in 10 seconds.'
          : 'Take 10 seconds to record today\'s transactions and build your streak.';

      await _notificationsPlugin.show(
        9999, // dedicated streak notification ID
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Error showing streak reminder: $e');
    }
  }

  Future<void> showLoanReminderNotification({
    required int id,
    required String personName,
    required String type,
    required String amountFormatted,
    required DateTime? dueDate,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'loan_reminders',
        'Loan & Debt Reminders',
        channelDescription: 'Reminders for dues and debts payback dates',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      final isLent = type == 'lent';
      final title = isLent
          ? '💰 Due Reminder: $personName'
          : '💳 Debt Reminder: Pay $personName';
      final body = isLent
          ? '$personName is expected to return $amountFormatted.'
          : 'You are scheduled to repay $amountFormatted to $personName.';

      await _notificationsPlugin.show(
        id,
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Error showing loan reminder: $e');
    }
  }
}

