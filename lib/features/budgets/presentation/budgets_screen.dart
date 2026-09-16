import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/presentation/widgets/safe_to_spend_card.dart';
import '../../milestones/providers/milestones_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/budgets_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  void _showAddEditBudgetDialog(BuildContext context, WidgetRef ref, {BudgetWithCategory? existing}) {
    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);
    final selectedMonth = ref.read(selectedBudgetMonthProvider);

    final amountController = TextEditingController(
      text: existing != null ? (existing.budget.amountCents / 100.0).toStringAsFixed(2) : '',
    );
    int? selectedCatId = existing?.category.id;
    String selectedPeriod = existing?.budget.period ?? 'monthly';
    bool rollover = existing?.budget.rolloverEnabled ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Budget' : 'Create Category Budget'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Dropdown
                  FutureBuilder<List<Category>>(
                    future: db.getCategories(type: 'expense'),
                    builder: (context, snapshot) {
                      final rawCategories = snapshot.data ?? [];
                      final seenIds = <int>{};
                      final categories = rawCategories.where((c) => seenIds.add(c.id)).toList();
                      if (categories.isEmpty) return const SizedBox.shrink();

                      if (selectedCatId == null || !categories.any((c) => c.id == selectedCatId)) {
                        selectedCatId = categories.first.id;
                      }

                      return DropdownButtonFormField<int>(
                        key: ValueKey('budget_cat_$selectedCatId'),
                        initialValue: selectedCatId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories.map((c) {
                          return DropdownMenuItem<int>(
                            value: c.id,
                            child: Row(
                              children: [
                                Icon(IconHelper.getIcon(c.icon), color: Color(c.colorValue), size: 18),
                                const SizedBox(width: 8),
                                Text(c.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => selectedCatId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Amount Limit
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Budget Limit (${currency.symbol})',
                      hintText: 'e.g. 500.00',
                      prefixText: '${currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Period (Weekly, Monthly, Yearly)
                  DropdownButtonFormField<String>(
                    initialValue: selectedPeriod,
                    decoration: const InputDecoration(labelText: 'Period'),
                    items: const [
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (val) => setState(() => selectedPeriod = val ?? 'monthly'),
                  ),
                  const SizedBox(height: 14),

                  // Rollover Switch
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Rollover', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Carry unspent balance to next period', style: TextStyle(fontSize: 12)),
                    value: rollover,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) => setState(() => rollover = val),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    await (db.delete(db.budgets)..where((b) => b.id.equals(existing.budget.id))).go();
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Delete', style: TextStyle(color: AppColors.expense)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final cents = CurrencyFormatter.parseAmountToCents(amountController.text);
                  if (cents == null || cents <= 0 || selectedCatId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid budget amount')),
                    );
                    return;
                  }

                  if (existing != null) {
                    await (db.update(db.budgets)..where((b) => b.id.equals(existing.budget.id))).write(
                      BudgetsCompanion(
                        categoryId: drift.Value(selectedCatId!),
                        amountCents: drift.Value(cents),
                        period: drift.Value(selectedPeriod),
                        rolloverEnabled: drift.Value(rollover),
                      ),
                    );
                  } else {
                    await db.into(db.budgets).insert(
                      BudgetsCompanion.insert(
                        categoryId: selectedCatId!,
                        amountCents: cents,
                        period: drift.Value(selectedPeriod),
                        startDate: selectedMonth,
                        rolloverEnabled: drift.Value(rollover),
                      ),
                    );
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: Text(existing != null ? 'Save Changes' : 'Create Budget'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsWithProgressProvider);
    final selectedMonth = ref.watch(selectedBudgetMonthProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Budget',
            onPressed: () => _showAddEditBudgetDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Month Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    ref.read(selectedBudgetMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                  },
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMMM yyyy').format(selectedMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    ref.read(selectedBudgetMonthProvider.notifier).state =
                        DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: budgetsAsync.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SafeToSpendCard(isBudgetsScreen: true),
                      const SizedBox(height: 36),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tune, size: 60, color: Colors.grey.withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            const Text(
                              'No budgets set for this month',
                              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set category spending limits to keep your expenses on track',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEditBudgetDialog(context, ref),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create Category Budget'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // Summary calculations
                int totalBudgeted = 0;
                int totalSpent = 0;
                for (final b in budgets) {
                  totalBudgeted += b.budget.amountCents;
                  totalSpent += b.spentCents;
                }
                final totalRemaining = totalBudgeted - totalSpent;
                final totalProgress = totalBudgeted > 0 ? (totalSpent / totalBudgeted).clamp(0.0, 1.0) : 0.0;

                // Check budget_under_month_1 milestone if past month was under budget
                if (selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month, 1)) &&
                    budgets.isNotEmpty &&
                    totalSpent <= totalBudgeted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(milestoneProvider.notifier).triggerMilestone('budget_under_month_1');
                  });
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SafeToSpendCard(isBudgetsScreen: true),
                    const SizedBox(height: 14),

                    // Overall Budget Header Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Monthly Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: totalRemaining >= 0
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : AppColors.expense.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    totalRemaining >= 0
                                        ? '${CurrencyFormatter.formatCents(totalRemaining, symbol: currency.symbol)} Left'
                                        : '${CurrencyFormatter.formatCents(totalRemaining.abs(), symbol: currency.symbol)} Over',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: totalRemaining >= 0 ? AppColors.primary : AppColors.expense,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Spent: ${CurrencyFormatter.formatCents(totalSpent, symbol: currency.symbol)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
                                ),
                                Text(
                                  'Limit: ${CurrencyFormatter.formatCents(totalBudgeted, symbol: currency.symbol)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: totalProgress,
                                minHeight: 10,
                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  totalSpent > totalBudgeted
                                      ? AppColors.budgetExceeded
                                      : totalProgress >= 0.8
                                          ? AppColors.budgetWarning
                                          : AppColors.budgetNormal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Category Budgets',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),

                    // Category Budget Cards
                    ...budgets.map((b) {
                      final isExceeded = b.isExceeded;
                      final isWarning = b.isWarning;
                      final progressColor = isExceeded
                          ? AppColors.budgetExceeded
                          : isWarning
                              ? AppColors.budgetWarning
                              : AppColors.budgetNormal;

                      final spentStr = CurrencyFormatter.formatCents(b.spentCents, symbol: currency.symbol);
                      final limitStr = CurrencyFormatter.formatCents(b.budget.amountCents, symbol: currency.symbol);
                      final remStr = CurrencyFormatter.formatCents(b.remainingCents.abs(), symbol: currency.symbol);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showAddEditBudgetDialog(context, ref, existing: b),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Color(b.category.colorValue).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        IconHelper.getIcon(b.category.icon),
                                        color: Color(b.category.colorValue),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.category.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Text(
                                            isExceeded
                                                ? 'Over by $remStr (${(b.progress * 100).toInt()}%)'
                                                : '$remStr remaining (${(b.progress * 100).toInt()}% used)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isExceeded ? AppColors.expense : Colors.grey,
                                              fontWeight: isExceeded ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          spentStr,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isExceeded ? AppColors.expense : null,
                                          ),
                                        ),
                                        Text('of $limitStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: b.progress.clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor: progressColor.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditBudgetDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
