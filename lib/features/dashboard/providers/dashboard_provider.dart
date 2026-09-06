import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/date_utils.dart';

class DashboardSummary {
  final int totalBalanceCents;
  final int thisMonthIncomeCents;
  final int thisMonthExpenseCents;
  final int thisMonthNetCents;
  final List<CategorySpendSummary> topCategories;

  DashboardSummary({
    required this.totalBalanceCents,
    required this.thisMonthIncomeCents,
    required this.thisMonthExpenseCents,
    required this.thisMonthNetCents,
    required this.topCategories,
  });
}

class CategorySpendSummary {
  final Category category;
  final int amountCents;
  final double percentage;

  CategorySpendSummary({
    required this.category,
    required this.amountCents,
    required this.percentage,
  });
}

final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final mStart = AppDateUtils.startOfMonth(now);
  final mEnd = AppDateUtils.endOfMonth(now);

  return db.watchRecentTransactions(limit: 1).asyncMap((_) async {
    final balances = await db.calculateAllAccountBalances();
    final totalNet = balances.values.fold<int>(0, (sum, b) => sum + b);

    final categories = await db.getCategories();
    final thisMonthTx = await db.getTransactionsForDateRange(mStart, mEnd);

    final catMap = {for (var c in categories) c.id: c};

    // Monthly Income & Expense
    int inc = 0;
    int exp = 0;
    final Map<int, int> catSpendMap = {};

    for (final t in thisMonthTx) {
      if (t.transaction.type == 'income') {
        inc += t.transaction.amountCents;
      } else if (t.transaction.type == 'expense') {
        exp += t.transaction.amountCents;
        if (t.transaction.categoryId != null) {
          final cid = t.transaction.categoryId!;
          catSpendMap[cid] = (catSpendMap[cid] ?? 0) + t.transaction.amountCents;
        }
      }
    }

    final net = inc - exp;

    // Build top category spends
    final List<CategorySpendSummary> topCats = [];
    catSpendMap.forEach((cid, amount) {
      final cat = catMap[cid];
      if (cat != null) {
        final pct = exp > 0 ? (amount / exp) : 0.0;
        topCats.add(CategorySpendSummary(category: cat, amountCents: amount, percentage: pct));
      }
    });

    topCats.sort((a, b) => b.amountCents.compareTo(a.amountCents));

    return DashboardSummary(
      totalBalanceCents: totalNet,
      thisMonthIncomeCents: inc,
      thisMonthExpenseCents: exp,
      thisMonthNetCents: net,
      topCategories: topCats,
    );
  });
});

