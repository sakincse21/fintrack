import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../database/database.dart';
import '../utils/currency_formatter.dart';
import 'notification_service.dart';

class RecurringEngineService {
  final AppDatabase db;
  final NotificationService notificationService;

  RecurringEngineService(this.db, this.notificationService);

  /// Checks and posts all pending recurring transactions up to current date
  Future<int> processDueRecurringTransactions() async {
    final now = DateTime.now();
    final dueRules = await db.getDueRecurringRules(now);
    int postedCount = 0;

    for (final rule in dueRules) {
      DateTime currentRunDate = rule.nextRunDate;

      // Prevent infinite loop if rule is way in the past: process up to current time
      while (currentRunDate.isBefore(now) ||
          currentRunDate.isAtSameMomentAs(now)) {
        // If end_date passed, disable rule and break
        if (rule.endDate != null && currentRunDate.isAfter(rule.endDate!)) {
          await (db.update(db.recurringRules)..where((r) => r.id.equals(rule.id)))
              .write(const RecurringRulesCompanion(isActive: Value(false)));
          break;
        }

        // Insert generated transaction
        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            accountId: rule.accountId,
            categoryId: Value(rule.categoryId),
            amountCents: rule.amountCents,
            type: rule.type,
            note: Value(rule.note),
            date: currentRunDate,
            isRecurring: const Value(true),
            recurringId: Value(rule.id),
          ),
        );
        postedCount++;

        // Notify user about posted bill
        final formattedAmount = CurrencyFormatter.formatCents(rule.amountCents);
        await notificationService.showRecurringBillReminder(
          id: rule.id,
          note: rule.note.isNotEmpty ? rule.note : 'Recurring ${rule.type}',
          amountFormatted: formattedAmount,
          date: currentRunDate,
        );

        // Advance to next run date
        currentRunDate = _calculateNextRunDate(
          currentRunDate,
          rule.frequency,
          rule.interval,
        );

        // Update rule nextRunDate in DB
        await (db.update(db.recurringRules)..where((r) => r.id.equals(rule.id)))
            .write(RecurringRulesCompanion(nextRunDate: Value(currentRunDate)));
      }
    }

    if (postedCount > 0) {
      debugPrint('RecurringEngineService: Processed $postedCount recurring transactions.');
    }

    return postedCount;
  }

  DateTime _calculateNextRunDate(
    DateTime current,
    String frequency,
    int interval,
  ) {
    final safeInterval = interval <= 0 ? 1 : interval;

    switch (frequency.toLowerCase()) {
      case 'daily':
        return current.add(Duration(days: safeInterval));
      case 'weekly':
        return current.add(Duration(days: 7 * safeInterval));
      case 'yearly':
        return DateTime(
          current.year + safeInterval,
          current.month,
          current.day,
          current.hour,
          current.minute,
        );
      case 'monthly':
      default:
        // Handle variable month lengths safely
        int nextYear = current.year;
        int nextMonth = current.month + safeInterval;
        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear += 1;
        }
        final daysInNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        final nextDay = current.day > daysInNextMonth ? daysInNextMonth : current.day;
        return DateTime(nextYear, nextMonth, nextDay, current.hour, current.minute);
    }
  }
}

