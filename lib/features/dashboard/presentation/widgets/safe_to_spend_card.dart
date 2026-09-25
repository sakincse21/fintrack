import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/safe_to_spend_provider.dart';

class SafeToSpendCard extends ConsumerWidget {
  final bool isBudgetsScreen;

  const SafeToSpendCard({
    super.key,
    this.isBudgetsScreen = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final safeToSpendAsync = ref.watch(safeToSpendProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return safeToSpendAsync.when(
      data: (data) {
        // Edge Case: No budgets and zero/no transactions yet
        if (!data.hasBudgets && data.safeToSpendCents == 0 && data.totalSpentCents == 0) {
          return InkWell(
            onTap: isBudgetsScreen ? null : () => context.push('/budgets'),
            borderRadius: BorderRadius.circular(26),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.security_outlined,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Safe to Spend',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Set a monthly budget to unlock your daily safe-to-spend target.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isBudgetsScreen)
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                ],
              ),
            ),
          );
        }

        final isNegative = data.safeToSpendCents < 0;
        final pct = data.remainingPercentage;

        // Three-tier color logic:
        // Green if positive and > 20% remains, Amber if positive and <= 20%, Red if negative
        final Color statusColor = isNegative
            ? AppColors.expense
            : (pct > 0.20 ? AppColors.income : AppColors.warning);

        final String subtitle = isNegative
            ? 'over budget this month'
            : 'left to spend this month';

        return InkWell(
          onTap: isBudgetsScreen ? null : () => context.push('/budgets'),
          borderRadius: BorderRadius.circular(26),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: isDark ? 0.08 : 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isNegative ? Icons.warning_amber_rounded : Icons.security_outlined,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SAFE TO SPEND',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (!isBudgetsScreen)
                      Row(
                        children: [
                          Text(
                            'Budgets',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Large Tabular Number
                Text(
                  CurrencyFormatter.formatCents(data.safeToSpendCents, symbol: currency.symbol),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),

                // Subtitle
                Row(
                  children: [
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isNegative
                            ? AppColors.expense
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                    if (data.upcomingBillsCents > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${CurrencyFormatter.formatCompact(data.upcomingBillsCents, symbol: currency.symbol)} bills reserved)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),

                // Helper hint when no explicit budgets are set
                if (!data.hasBudgets) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Set category budgets to sharpen this calculation',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

