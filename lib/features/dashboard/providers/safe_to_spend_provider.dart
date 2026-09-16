import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../budgets/providers/budgets_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/dashboard_provider.dart';

class SafeToSpendData {
  final int safeToSpendCents;
  final int totalBudgetedCents;
  final int totalSpentCents;
  final int upcomingBillsCents;
  final int goalCommitmentsCents;
  final bool hasBudgets;
  final bool isStrict;

  const SafeToSpendData({
    required this.safeToSpendCents,
    required this.totalBudgetedCents,
    required this.totalSpentCents,
    required this.upcomingBillsCents,
    required this.goalCommitmentsCents,
    required this.hasBudgets,
    required this.isStrict,
  });

  /// Percentage of budget remaining (0.0 to 1.0, or negative if overspent)
  double get remainingPercentage {
    final base = hasBudgets ? totalBudgetedCents : (totalBudgetedCents > 0 ? totalBudgetedCents : (totalSpentCents + safeToSpendCents));
    if (base <= 0) return safeToSpendCents > 0 ? 1.0 : 0.0;
    return safeToSpendCents / base;
  }
}

final safeToSpendProvider = Provider<AsyncValue<SafeToSpendData>>((ref) {
  final budgetsAsync = ref.watch(budgetsWithProgressProvider);
  final recurringAsync = ref.watch(activeRecurringRulesProvider);
  final goalsAsync = ref.watch(goalsListProvider);
  final isStrict = ref.watch(includeGoalsInSafeToSpendProvider);
  final dashboardSummaryAsync = ref.watch(dashboardSummaryProvider);

  if (budgetsAsync.isLoading || recurringAsync.isLoading || dashboardSummaryAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (budgetsAsync.hasError) {
    return AsyncValue.error(budgetsAsync.error!, budgetsAsync.stackTrace!);
  }

  final budgets = budgetsAsync.value ?? [];
  final recurring = recurringAsync.value ?? [];
  final goals = goalsAsync.value ?? [];
  final summary = dashboardSummaryAsync.value;

  final now = DateTime.now();
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // 1. Total budgeted & spent across category budgets
  final totalBudgeted = budgets.fold<int>(0, (sum, b) => sum + b.budget.amountCents);
  final totalSpent = budgets.fold<int>(0, (sum, b) => sum + b.spentCents);

  // 2. Upcoming unpaid bills due before month end
  final upcomingBills = recurring.where((r) {
    final next = r.rule.nextRunDate;
    return r.rule.type == 'expense' &&
        next.isAfter(now) &&
        next.isBefore(endOfMonth);
  }).fold<int>(0, (sum, r) => sum + r.rule.amountCents);

  // 3. Optional goal commitment in strict mode
  int goalCommitments = 0;
  if (isStrict) {
    for (final g in goals) {
      goalCommitments += g.suggestedMonthlyContributionCents;
    }
  }

  if (totalBudgeted > 0) {
    // Primary formula with configured budgets
    final safeToSpend = totalBudgeted - totalSpent - upcomingBills - goalCommitments;
    return AsyncValue.data(SafeToSpendData(
      safeToSpendCents: safeToSpend,
      totalBudgetedCents: totalBudgeted,
      totalSpentCents: totalSpent,
      upcomingBillsCents: upcomingBills,
      goalCommitmentsCents: goalCommitments,
      hasBudgets: true,
      isStrict: isStrict,
    ));
  } else {
    // Fallback formula when no budgets are set
    final income = summary?.thisMonthIncomeCents ?? 0;
    final expenses = summary?.thisMonthExpenseCents ?? 0;
    final fallbackSafe = income - expenses - upcomingBills - goalCommitments;

    return AsyncValue.data(SafeToSpendData(
      safeToSpendCents: fallbackSafe,
      totalBudgetedCents: 0,
      totalSpentCents: expenses,
      upcomingBillsCents: upcomingBills,
      goalCommitmentsCents: goalCommitments,
      hasBudgets: false,
      isStrict: isStrict,
    ));
  }
});
