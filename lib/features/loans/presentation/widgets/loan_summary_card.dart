import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/loans_provider.dart';

class LoanSummaryCard extends ConsumerWidget {
  const LoanSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(loanSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasActiveLoans) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () => context.push('/dues-debts'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 18, color: AppColors.warning),
                      const SizedBox(width: 10),
                      const Text(
                        'Dues & Debts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (summary.overdueCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${summary.overdueCount} overdue',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[400]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (summary.activeLentCount > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "You're owed",
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatCents(summary.totalLentCents, symbol: currency.symbol),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (summary.activeBorrowedCount > 0)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: summary.activeLentCount > 0
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You owe',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatCents(summary.totalBorrowedCents, symbol: currency.symbol),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

