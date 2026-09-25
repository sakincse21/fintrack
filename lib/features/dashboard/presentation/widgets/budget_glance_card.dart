import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/default_categories.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../budgets/providers/budgets_provider.dart';
import '../../../settings/providers/settings_provider.dart';

class BudgetGlanceCard extends ConsumerWidget {
  const BudgetGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsWithProgressProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Budgets',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
              ),
              InkWell(
                onTap: () => context.go('/budgets'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 40, color: Colors.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(
                          'No active budgets set for this month',
                          style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/budgets'),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Create Budget', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: budgets.take(3).map((item) {
                  final budget = item.budget;
                  final cat = item.category;
                  final progress = item.progress.clamp(0.0, 1.0);
                  final isOver = item.isExceeded;
                  final isNear = item.isWarning;

                  final barColor = isOver
                      ? AppColors.expense
                      : isNear
                          ? AppColors.warning
                          : AppColors.income;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              IconHelper.getIcon(cat.icon),
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.formatCents(item.spentCents, symbol: currency.symbol)} / ${CurrencyFormatter.formatCents(budget.amountCents, symbol: currency.symbol)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isOver ? AppColors.expense : isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                            minHeight: 7,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
