import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../recurring/providers/recurring_provider.dart';
import '../../../settings/providers/settings_provider.dart';

class SubscriptionsGlanceCard extends ConsumerWidget {
  const SubscriptionsGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return subscriptionsAsync.when(
      data: (summary) {
        if (summary.items.isEmpty) return const SizedBox.shrink();

        return InkWell(
          onTap: () => context.push('/subscriptions'),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Subscriptions',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${summary.activeCount}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${CurrencyFormatter.formatCents(summary.totalMonthlyCents, symbol: currency.symbol)} / month total',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
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

