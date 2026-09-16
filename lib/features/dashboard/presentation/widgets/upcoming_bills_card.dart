import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/default_categories.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../recurring/providers/recurring_provider.dart';
import '../../../settings/providers/settings_provider.dart';

class UpcomingBillsCard extends ConsumerWidget {
  const UpcomingBillsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingBillsAsync = ref.watch(upcomingBillsNext7DaysProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final db = ref.watch(databaseProvider);

    return upcomingBillsAsync.when(
      data: (bills) {
        if (bills.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendarClock, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Upcoming Bills (7 Days)',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...bills.map((item) {
                final rule = item.rule;
                final cat = item.category;
                final catColor = cat != null ? Color(cat.colorValue) : AppColors.primary;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          IconHelper.getIcon(cat?.icon ?? 'receipt_long'),
                          color: catColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rule.note.isNotEmpty ? rule.note : (cat?.name ?? 'Recurring Bill'),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              'Due ${AppDateUtils.formatRelative(rule.nextRunDate)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCents(rule.amountCents, symbol: currency.symbol),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(LucideIcons.circleCheck, color: AppColors.primary, size: 20),
                        tooltip: 'Mark Paid & Log',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await db.into(db.transactions).insert(
                            TransactionsCompanion.insert(
                              accountId: rule.accountId,
                              categoryId: drift.Value(rule.categoryId),
                              amountCents: rule.amountCents,
                              type: rule.type,
                              note: drift.Value(rule.note),
                              date: DateTime.now(),
                              isRecurring: const drift.Value(true),
                              recurringId: drift.Value(rule.id),
                            ),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bill marked as paid & logged!')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
