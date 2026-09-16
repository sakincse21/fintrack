import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/date_utils.dart';

// Filter state for reports
class ReportFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStart;
  final DateTime? customEnd;
  final Set<int> selectedAccountIds;
  final Set<int> selectedCategoryIds;
  final String selectedType; // 'all', 'expense', 'transfer', 'income'

  const ReportFilterState({
    this.dateRangeFilter = DateRangeFilter.thisMonth,
    this.customStart,
    this.customEnd,
    this.selectedAccountIds = const {},
    this.selectedCategoryIds = const {},
    this.selectedType = 'all',
  });

  // Backward compatibility getter for single accountId
  int? get accountId => selectedAccountIds.isEmpty ? null : selectedAccountIds.first;

  DateRange get effectiveRange => DateRange.fromFilter(
        dateRangeFilter,
        customStart: customStart,
        customEnd: customEnd,
      );

  int get activeFiltersCount {
    int count = 0;
    if (dateRangeFilter != DateRangeFilter.thisMonth) count++;
    if (selectedAccountIds.isNotEmpty) count += selectedAccountIds.length;
    if (selectedCategoryIds.isNotEmpty) count += selectedCategoryIds.length;
    if (selectedType != 'all') count++;
    return count;
  }

  ReportFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTime? customStart,
    DateTime? customEnd,
    int? accountId,
    Set<int>? selectedAccountIds,
    Set<int>? selectedCategoryIds,
    String? selectedType,
    bool clearAccount = false,
    bool clearAccounts = false,
    bool clearCategories = false,
  }) {
    Set<int>? nextAccounts;
    if (clearAccount || clearAccounts) {
      nextAccounts = const {};
    } else if (selectedAccountIds != null) {
      nextAccounts = selectedAccountIds;
    } else if (accountId != null) {
      nextAccounts = {accountId};
    } else {
      nextAccounts = this.selectedAccountIds;
    }

    return ReportFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
      selectedAccountIds: nextAccounts,
      selectedCategoryIds: clearCategories ? const {} : (selectedCategoryIds ?? this.selectedCategoryIds),
      selectedType: selectedType ?? this.selectedType,
    );
  }
}

final reportFilterProvider =
    StateNotifierProvider<ReportFilterNotifier, ReportFilterState>((ref) {
  return ReportFilterNotifier();
});

class ReportFilterNotifier extends StateNotifier<ReportFilterState> {
  ReportFilterNotifier() : super(const ReportFilterState());

  void setFilter(DateRangeFilter filter, {DateTime? start, DateTime? end}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStart: start,
      customEnd: end,
    );
  }

  void toggleAccount(int accountId) {
    final current = Set<int>.from(state.selectedAccountIds);
    if (current.contains(accountId)) {
      current.remove(accountId);
    } else {
      current.add(accountId);
    }
    state = state.copyWith(selectedAccountIds: current);
  }

  void setAccount(int? accountId) {
    if (accountId == null) {
      state = state.copyWith(clearAccounts: true);
    } else {
      state = state.copyWith(selectedAccountIds: {accountId});
    }
  }

  void clearAccounts() {
    state = state.copyWith(clearAccounts: true);
  }

  void toggleCategory(int categoryId) {
    final current = Set<int>.from(state.selectedCategoryIds);
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    state = state.copyWith(selectedCategoryIds: current);
  }

  void clearCategories() {
    state = state.copyWith(clearCategories: true);
  }

  void setType(String type) {
    state = state.copyWith(selectedType: type);
  }

  void reset() {
    state = const ReportFilterState();
  }
}

// Data models for analytics
class MonthlyTrendPoint {
  final DateTime monthDate;
  final String label; // "Jan 26"
  final int incomeCents;
  final int expenseCents;
  final int transferCents;
  final int netCents;
  final double savingsRate; // 0% to 100%

  MonthlyTrendPoint({
    required this.monthDate,
    required this.label,
    required this.incomeCents,
    required this.expenseCents,
    this.transferCents = 0,
    required this.netCents,
    required this.savingsRate,
  });
}

class CategoryBreakdownItem {
  final Category category;
  final int totalCents;
  final double percentage; // 0.0 to 1.0
  final int transactionCount;

  CategoryBreakdownItem({
    required this.category,
    required this.totalCents,
    required this.percentage,
    required this.transactionCount,
  });
}

class TagBreakdownItem {
  final String tag;
  final int totalCents;
  final int count;

  TagBreakdownItem({
    required this.tag,
    required this.totalCents,
    required this.count,
  });
}

class AccountBreakdownItem {
  final Account account;
  final int totalSpentCents;
  final int totalIncomeCents;
  final int currentBalanceCents;

  AccountBreakdownItem({
    required this.account,
    required this.totalSpentCents,
    required this.totalIncomeCents,
    required this.currentBalanceCents,
  });
}

class MerchantRankItem {
  final String merchant;
  final int totalCents;
  final int count;
  final Category? category;

  MerchantRankItem({
    required this.merchant,
    required this.totalCents,
    required this.count,
    this.category,
  });
}

class DayOfWeekSpendItem {
  final int weekday; // 1 (Mon) - 7 (Sun)
  final String dayName;
  final int totalCents;

  DayOfWeekSpendItem({
    required this.weekday,
    required this.dayName,
    required this.totalCents,
  });
}

class TimeOfMonthSpendItem {
  final String period; // "1-10", "11-20", "21-End"
  final int totalCents;

  TimeOfMonthSpendItem({
    required this.period,
    required this.totalCents,
  });
}

class MonthOverMonthComparison {
  final int currentMonthIncomeCents;
  final int currentMonthExpenseCents;
  final int lastMonthIncomeCents;
  final int lastMonthExpenseCents;

  MonthOverMonthComparison({
    required this.currentMonthIncomeCents,
    required this.currentMonthExpenseCents,
    required this.lastMonthIncomeCents,
    required this.lastMonthExpenseCents,
  });

  int get expenseDifferenceCents =>
      currentMonthExpenseCents - lastMonthExpenseCents;

  double get expenseChangePercent {
    if (lastMonthExpenseCents == 0) return 0.0;
    return (expenseDifferenceCents / lastMonthExpenseCents) * 100.0;
  }
}

class FullAnalyticsReport {
  final DateRange dateRange;
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int totalTransferCents;
  final int netSavingsCents;
  final double overallSavingsRate;
  final List<MonthlyTrendPoint> monthlyTrends; // Last 6-12 months
  final List<CategoryBreakdownItem> categoryBreakdowns;
  final MonthOverMonthComparison momComparison;
  final List<TagBreakdownItem> tagBreakdowns;
  final List<AccountBreakdownItem> accountBreakdowns;
  final List<MerchantRankItem> topMerchants;
  final List<DayOfWeekSpendItem> dayOfWeekSpends;
  final List<TimeOfMonthSpendItem> timeOfMonthSpends;

  FullAnalyticsReport({
    required this.dateRange,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    this.totalTransferCents = 0,
    required this.netSavingsCents,
    required this.overallSavingsRate,
    required this.monthlyTrends,
    required this.categoryBreakdowns,
    required this.momComparison,
    required this.tagBreakdowns,
    required this.accountBreakdowns,
    required this.topMerchants,
    required this.dayOfWeekSpends,
    required this.timeOfMonthSpends,
  });
}

// Compute full analytics reactive to database & filter changes
final fullAnalyticsProvider = StreamProvider<FullAnalyticsReport>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(reportFilterProvider);
  final range = filter.effectiveRange;

  // Watch transactions to ensure live updates
  return db.watchRecentTransactions(limit: 1).asyncMap((_) async {
    // 1. Fetch transactions within selected date range with active filters
    final rangeTx = await db.getTransactionsForDateRange(
      range.start,
      range.end,
      accountIds: filter.selectedAccountIds,
      categoryIds: filter.selectedCategoryIds,
      type: filter.selectedType,
    );
    final allAccounts = await db.getAllAccounts();
    final allCategories = await db.getCategories();

    final catMap = {for (var c in allCategories) c.id: c};

    // Calculate totals for range
    int totalIncome = 0;
    int totalExpense = 0;
    int totalTransfer = 0;
    final Map<int, int> categoryTotals = {};
    final Map<int, int> categoryCounts = {};
    final Map<String, int> tagTotals = {};
    final Map<String, int> tagCounts = {};
    final Map<String, int> merchantTotals = {};
    final Map<String, int> merchantCounts = {};
    final Map<String, Category?> merchantCat = {};
    final Map<int, int> accountSpent = {};
    final Map<int, int> accountIncome = {};

    final Map<int, int> weekdaySpend = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    int earlyMonthSpend = 0; // 1 - 10
    int midMonthSpend = 0;   // 11 - 20
    int lateMonthSpend = 0;  // 21 - End

    final isIncomeOnly = filter.selectedType == 'income';
    final isTransferOnly = filter.selectedType == 'transfer';

    for (final item in rangeTx) {
      final tx = item.transaction;
      if (tx.type == 'income') {
        totalIncome += tx.amountCents;
        accountIncome[tx.accountId] = (accountIncome[tx.accountId] ?? 0) + tx.amountCents;

        if (isIncomeOnly && tx.categoryId != null) {
          categoryTotals[tx.categoryId!] = (categoryTotals[tx.categoryId!] ?? 0) + tx.amountCents;
          categoryCounts[tx.categoryId!] = (categoryCounts[tx.categoryId!] ?? 0) + 1;
        }
      } else if (tx.type == 'expense') {
        totalExpense += tx.amountCents;
        accountSpent[tx.accountId] = (accountSpent[tx.accountId] ?? 0) + tx.amountCents;

        // Category breakdown
        if (!isIncomeOnly && !isTransferOnly && tx.categoryId != null) {
          categoryTotals[tx.categoryId!] = (categoryTotals[tx.categoryId!] ?? 0) + tx.amountCents;
          categoryCounts[tx.categoryId!] = (categoryCounts[tx.categoryId!] ?? 0) + 1;
        }

        // Tags breakdown
        if (tx.tagIds.isNotEmpty) {
          final tags = tx.tagIds.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
          for (final t in tags) {
            tagTotals[t] = (tagTotals[t] ?? 0) + tx.amountCents;
            tagCounts[t] = (tagCounts[t] ?? 0) + 1;
          }
        }

        // Top merchants / notes
        final noteKey = tx.note.trim().isNotEmpty ? tx.note.trim() : (item.category?.name ?? 'Expense');
        merchantTotals[noteKey] = (merchantTotals[noteKey] ?? 0) + tx.amountCents;
        merchantCounts[noteKey] = (merchantCounts[noteKey] ?? 0) + 1;
        merchantCat[noteKey] = item.category;

        // Day of week (1 = Monday, 7 = Sunday)
        final wd = tx.date.weekday;
        weekdaySpend[wd] = (weekdaySpend[wd] ?? 0) + tx.amountCents;

        // Time of month
        if (tx.date.day <= 10) {
          earlyMonthSpend += tx.amountCents;
        } else if (tx.date.day <= 20) {
          midMonthSpend += tx.amountCents;
        } else {
          lateMonthSpend += tx.amountCents;
        }
      } else if (tx.type == 'transfer') {
        totalTransfer += tx.amountCents;
        accountSpent[tx.accountId] = (accountSpent[tx.accountId] ?? 0) + tx.amountCents;
        if (tx.toAccountId != null) {
          accountIncome[tx.toAccountId!] = (accountIncome[tx.toAccountId!] ?? 0) + tx.amountCents;
        }

        if (isTransferOnly && tx.categoryId != null) {
          categoryTotals[tx.categoryId!] = (categoryTotals[tx.categoryId!] ?? 0) + tx.amountCents;
          categoryCounts[tx.categoryId!] = (categoryCounts[tx.categoryId!] ?? 0) + 1;
        }

        if (isTransferOnly && tx.tagIds.isNotEmpty) {
          final tags = tx.tagIds.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty);
          for (final t in tags) {
            tagTotals[t] = (tagTotals[t] ?? 0) + tx.amountCents;
            tagCounts[t] = (tagCounts[t] ?? 0) + 1;
          }
        }

        final noteKey = tx.note.trim().isNotEmpty ? tx.note.trim() : (item.category?.name ?? 'Transfer');
        merchantTotals[noteKey] = (merchantTotals[noteKey] ?? 0) + tx.amountCents;
        merchantCounts[noteKey] = (merchantCounts[noteKey] ?? 0) + 1;
        merchantCat[noteKey] = item.category;

        if (isTransferOnly) {
          final wd = tx.date.weekday;
          weekdaySpend[wd] = (weekdaySpend[wd] ?? 0) + tx.amountCents;
          if (tx.date.day <= 10) {
            earlyMonthSpend += tx.amountCents;
          } else if (tx.date.day <= 20) {
            midMonthSpend += tx.amountCents;
          } else {
            lateMonthSpend += tx.amountCents;
          }
        }
      }
    }

    final netSavings = totalIncome - totalExpense;
    final overallSavingsRate = totalIncome > 0 ? (netSavings / totalIncome) * 100.0 : 0.0;

    // Build CategoryBreakdown list
    final List<CategoryBreakdownItem> categoryBreakdownList = [];
    final otherCat = Category(
      id: 0,
      name: 'Uncategorized',
      type: isIncomeOnly ? 'income' : (isTransferOnly ? 'transfer' : 'expense'),
      icon: 'category',
      colorValue: AppColors.categoryPalette.last.toARGB32(),
      parentId: null,
      isDefault: false,
    );

    final baseTotal = isIncomeOnly ? totalIncome : (isTransferOnly ? totalTransfer : totalExpense);

    categoryTotals.forEach((catId, total) {
      final cat = catMap[catId] ?? otherCat;
      final pct = baseTotal > 0 ? total / baseTotal : 0.0;
      categoryBreakdownList.add(CategoryBreakdownItem(
        category: cat,
        totalCents: total,
        percentage: pct,
        transactionCount: categoryCounts[catId] ?? 0,
      ));
    });
    categoryBreakdownList.sort((a, b) => b.totalCents.compareTo(a.totalCents));

    // Build TagBreakdown list
    final List<TagBreakdownItem> tagBreakdownList = [];
    tagTotals.forEach((tag, total) {
      tagBreakdownList.add(TagBreakdownItem(
        tag: tag,
        totalCents: total,
        count: tagCounts[tag] ?? 0,
      ));
    });
    tagBreakdownList.sort((a, b) => b.totalCents.compareTo(a.totalCents));

    // Build Top Merchants list
    final List<MerchantRankItem> topMerchantList = [];
    merchantTotals.forEach((merchant, total) {
      topMerchantList.add(MerchantRankItem(
        merchant: merchant,
        totalCents: total,
        count: merchantCounts[merchant] ?? 0,
        category: merchantCat[merchant],
      ));
    });
    topMerchantList.sort((a, b) => b.totalCents.compareTo(a.totalCents));

    // Build Account breakdown list (using fast single SQL aggregation)
    final allBalances = await db.calculateAllAccountBalances();
    final targetAccounts = filter.accountId != null
        ? allAccounts.where((a) => a.id == filter.accountId).toList()
        : allAccounts;

    final List<AccountBreakdownItem> accountBreakdownList = [];
    for (final acc in targetAccounts) {
      final bal = allBalances[acc.id] ?? acc.initialBalanceCents;
      accountBreakdownList.add(AccountBreakdownItem(
        account: acc,
        totalSpentCents: accountSpent[acc.id] ?? 0,
        totalIncomeCents: accountIncome[acc.id] ?? 0,
        currentBalanceCents: bal,
      ));
    }

    // Build Day of week list
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<DayOfWeekSpendItem> dayOfWeekList = [];
    for (int i = 1; i <= 7; i++) {
      dayOfWeekList.add(DayOfWeekSpendItem(
        weekday: i,
        dayName: dayNames[i - 1],
        totalCents: weekdaySpend[i] ?? 0,
      ));
    }

    // Build Time of month list
    final List<TimeOfMonthSpendItem> timeOfMonthList = [
      TimeOfMonthSpendItem(period: 'Days 1-10', totalCents: earlyMonthSpend),
      TimeOfMonthSpendItem(period: 'Days 11-20', totalCents: midMonthSpend),
      TimeOfMonthSpendItem(period: 'Days 21-End', totalCents: lateMonthSpend),
    ];

    // Build Monthly Trends for the past 6 months in parallel with filter
    final now = DateTime.now();
    final trendFutures = List.generate(6, (index) {
      final monthTarget = DateTime(now.year, now.month - (5 - index), 1);
      final mStart = AppDateUtils.startOfMonth(monthTarget);
      final mEnd = AppDateUtils.endOfMonth(monthTarget);

      return db.getTransactionsForDateRange(
        mStart,
        mEnd,
        accountIds: filter.selectedAccountIds,
        categoryIds: filter.selectedCategoryIds,
        type: filter.selectedType,
      ).then((mTx) {
        int mInc = 0;
        int mExp = 0;
        int mTrf = 0;
        for (final t in mTx) {
          if (t.transaction.type == 'income') {
            mInc += t.transaction.amountCents;
          } else if (t.transaction.type == 'expense') {
            mExp += t.transaction.amountCents;
          } else if (t.transaction.type == 'transfer') {
            mTrf += t.transaction.amountCents;
          }
        }
        final mNet = mInc - mExp;
        final mRate = mInc > 0 ? ((mNet / mInc) * 100.0).clamp(-100.0, 100.0) : 0.0;

        return MonthlyTrendPoint(
          monthDate: monthTarget,
          label: AppDateUtils.formatShortMonth(monthTarget),
          incomeCents: mInc,
          expenseCents: mExp,
          transferCents: mTrf,
          netCents: mNet,
          savingsRate: mRate,
        );
      });
    });

    final trendPoints = await Future.wait(trendFutures);

    // Month-over-Month Comparison (This month vs Last month in parallel with filter)
    final thisMonthStart = AppDateUtils.startOfMonth(now);
    final thisMonthEnd = AppDateUtils.endOfMonth(now);
    final lastMonthStart = AppDateUtils.startOfMonth(DateTime(now.year, now.month - 1, 1));
    final lastMonthEnd = AppDateUtils.endOfMonth(DateTime(now.year, now.month - 1, 1));

    final momResults = await Future.wait([
      db.getTransactionsForDateRange(
        thisMonthStart,
        thisMonthEnd,
        accountIds: filter.selectedAccountIds,
        categoryIds: filter.selectedCategoryIds,
        type: filter.selectedType,
      ),
      db.getTransactionsForDateRange(
        lastMonthStart,
        lastMonthEnd,
        accountIds: filter.selectedAccountIds,
        categoryIds: filter.selectedCategoryIds,
        type: filter.selectedType,
      ),
    ]);

    final thisMonthTx = momResults[0];
    final lastMonthTx = momResults[1];

    int curInc = 0, curExp = 0, lastInc = 0, lastExp = 0;
    for (final t in thisMonthTx) {
      if (t.transaction.type == 'income') curInc += t.transaction.amountCents;
      if (t.transaction.type == 'expense') curExp += t.transaction.amountCents;
    }
    for (final t in lastMonthTx) {
      if (t.transaction.type == 'income') lastInc += t.transaction.amountCents;
      if (t.transaction.type == 'expense') lastExp += t.transaction.amountCents;
    }

    final mom = MonthOverMonthComparison(
      currentMonthIncomeCents: curInc,
      currentMonthExpenseCents: curExp,
      lastMonthIncomeCents: lastInc,
      lastMonthExpenseCents: lastExp,
    );

    return FullAnalyticsReport(
      dateRange: range,
      totalIncomeCents: totalIncome,
      totalExpenseCents: totalExpense,
      totalTransferCents: totalTransfer,
      netSavingsCents: netSavings,
      overallSavingsRate: overallSavingsRate,
      monthlyTrends: trendPoints,
      categoryBreakdowns: categoryBreakdownList,
      momComparison: mom,
      tagBreakdowns: tagBreakdownList,
      accountBreakdowns: accountBreakdownList,
      topMerchants: topMerchantList,
      dayOfWeekSpends: dayOfWeekList,
      timeOfMonthSpends: timeOfMonthList,
    );
  });
});
