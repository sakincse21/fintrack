import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

class RecurringRuleWithDetails {
  final RecurringRule rule;
  final Account? account;
  final Category? category;

  RecurringRuleWithDetails({
    required this.rule,
    this.account,
    this.category,
  });
}

final activeRecurringRulesProvider =
    StreamProvider<List<RecurringRuleWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);

  return db.watchActiveRecurringRules().asyncMap((rules) async {
    final List<RecurringRuleWithDetails> result = [];
    final accounts = await db.getAllAccounts();
    final categories = await db.getCategories();

    final accMap = {for (var a in accounts) a.id: a};
    final catMap = {for (var c in categories) c.id: c};

    for (final rule in rules) {
      result.add(RecurringRuleWithDetails(
        rule: rule,
        account: accMap[rule.accountId],
        category: rule.categoryId != null ? catMap[rule.categoryId] : null,
      ));
    }

    return result;
  });
});

final upcomingBillsNext7DaysProvider =
    Provider<AsyncValue<List<RecurringRuleWithDetails>>>((ref) {
  final rulesAsync = ref.watch(activeRecurringRulesProvider);
  final now = DateTime.now();
  final endWindow = now.add(const Duration(days: 7));

  return rulesAsync.whenData((rules) {
    return rules.where((item) {
      final next = item.rule.nextRunDate;
      return next.isAfter(now.subtract(const Duration(hours: 12))) &&
          next.isBefore(endWindow);
    }).toList()
      ..sort((a, b) => a.rule.nextRunDate.compareTo(b.rule.nextRunDate));
  });
});

class SubscriptionItem {
  final RecurringRuleWithDetails details;
  final int monthlyNormalizedCents;
  final bool isUnused;

  SubscriptionItem({
    required this.details,
    required this.monthlyNormalizedCents,
    required this.isUnused,
  });

  static int normalizeToMonthly(int amountCents, String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return amountCents * 30;
      case 'weekly':
        return (amountCents * 4.333).round();
      case 'yearly':
        return (amountCents / 12).round();
      case 'monthly':
      default:
        return amountCents;
    }
  }

  static bool checkUnused(DateTime nextRunDate, String frequency) {
    final now = DateTime.now();
    if (nextRunDate.isAfter(now)) return false;
    final overdueDays = now.difference(nextRunDate).inDays;
    switch (frequency.toLowerCase()) {
      case 'weekly':
        return overdueDays > 7;
      case 'yearly':
        return overdueDays > 365;
      case 'monthly':
      default:
        return overdueDays > 30;
    }
  }
}

class SubscriptionsSummary {
  final List<SubscriptionItem> items;
  final int totalMonthlyCents;
  final int activeCount;

  SubscriptionsSummary({
    required this.items,
    required this.totalMonthlyCents,
    required this.activeCount,
  });
}

final subscriptionsProvider = Provider<AsyncValue<SubscriptionsSummary>>((ref) {
  final rulesAsync = ref.watch(activeRecurringRulesProvider);

  return rulesAsync.whenData((rules) {
    final subRules = rules.where((r) => r.rule.isSubscription).toList();
    final items = subRules.map((r) {
      final monthly = SubscriptionItem.normalizeToMonthly(
        r.rule.amountCents,
        r.rule.frequency,
      );
      final isUnused = SubscriptionItem.checkUnused(
        r.rule.nextRunDate,
        r.rule.frequency,
      );
      return SubscriptionItem(
        details: r,
        monthlyNormalizedCents: monthly,
        isUnused: isUnused,
      );
    }).toList()
      // Sort by highest cost first
      ..sort((a, b) => b.monthlyNormalizedCents.compareTo(a.monthlyNormalizedCents));

    final total = items.fold<int>(0, (sum, i) => sum + i.monthlyNormalizedCents);

    return SubscriptionsSummary(
      items: items,
      totalMonthlyCents: total,
      activeCount: items.length,
    );
  });
});

