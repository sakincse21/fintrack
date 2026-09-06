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

