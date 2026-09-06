import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../settings/providers/settings_provider.dart';

class CashFlowCard extends ConsumerWidget {
  final int incomeCents;
  final int expenseCents;
  final int netCents;

  const CashFlowCard({
    super.key,
    required this.incomeCents,
    required this.expenseCents,
    required this.netCents,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNetPositive = netCents >= 0;

    final savingsRate = incomeCents > 0
        ? ((netCents / incomeCents) * 100.0).clamp(-100.0, 100.0)
        : 0.0;

    return Column(
      children: [
        Row(
          children: [
            // Income Card (↗)
            Expanded(
              child: _buildFlowMetricCard(
                label: 'Income',
                amountCents: incomeCents,
                color: AppColors.income,
                bgTint: AppColors.income.withValues(alpha: 0.12),
                icon: LucideIcons.arrowUpRight,
                symbol: currency.symbol,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            // Expense Card (↘)
            Expanded(
              child: _buildFlowMetricCard(
                label: 'Expenses',
                amountCents: expenseCents,
                color: AppColors.expense,
                bgTint: AppColors.expense.withValues(alpha: 0.12),
                icon: LucideIcons.arrowDownRight,
                symbol: currency.symbol,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Net Savings Pill Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: (isNetPositive ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isNetPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                      size: 16,
                      color: isNetPositive ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Net Savings',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.formatCents(
                      netCents,
                      symbol: currency.symbol,
                      showSign: true,
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isNetPositive ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isNetPositive ? AppColors.income : AppColors.expense).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${savingsRate >= 0 ? '+' : ''}${savingsRate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isNetPositive ? AppColors.income : AppColors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowMetricCard({
    required String label,
    required int amountCents,
    required Color color,
    required Color bgTint,
    required IconData icon,
    required String symbol,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatCents(amountCents, symbol: symbol),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
