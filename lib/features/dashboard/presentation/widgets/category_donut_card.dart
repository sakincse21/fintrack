import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/default_categories.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../transactions/providers/transactions_provider.dart';
import '../../providers/dashboard_provider.dart';

class CategoryDonutCard extends ConsumerStatefulWidget {
  final List<CategorySpendSummary> categories;
  final int totalExpenseCents;

  const CategoryDonutCard({
    super.key,
    required this.categories,
    required this.totalExpenseCents,
  });

  @override
  ConsumerState<CategoryDonutCard> createState() => _CategoryDonutCardState();
}

class _CategoryDonutCardState extends ConsumerState<CategoryDonutCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.categories.isEmpty || widget.totalExpenseCents == 0) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Spending by Category',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('This Month', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Icon(Icons.donut_large_rounded, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 10),
            Text(
              'No expense logged yet this month',
              style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13.5),
            ),
          ],
        ),
      );
    }

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
                'Spending by Category',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
              ),
              InkWell(
                onTap: () => context.go('/reports'),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    'Full Analysis',
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
          const SizedBox(height: 18),
          Row(
            children: [
              // Donut Chart
              SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RepaintBoundary(
                      child: PieChart(
                        PieChartData(
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {
                              setState(() {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  _touchedIndex = -1;
                                  return;
                                }
                                _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              });
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          sectionsSpace: 3,
                          centerSpaceRadius: 42,
                          sections: _buildPieSections(),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Spent',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCompact(widget.totalExpenseCents, symbol: currency.symbol),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

              // Top 4 Ranked Categories
              Expanded(
                child: Column(
                  children: widget.categories.take(4).map((catSpend) {
                    final cat = catSpend.category;
                    final catColor = Color(cat.colorValue);

                    return InkWell(
                      onTap: () {
                        ref.read(transactionFilterProvider.notifier).reset();
                        ref.read(transactionFilterProvider.notifier).setCategory(cat.id);
                        context.go('/transactions');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: catColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(
                                IconHelper.getIcon(cat.icon),
                                size: 14,
                                color: catColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Text(
                              '${(catSpend.percentage * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final List<PieChartSectionData> sections = [];
    for (int i = 0; i < widget.categories.length; i++) {
      final item = widget.categories[i];
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 24.0 : 18.0;

      sections.add(
        PieChartSectionData(
          color: Color(item.category.colorValue),
          value: item.amountCents.toDouble(),
          title: '',
          radius: radius,
        ),
      );
    }
    return sections;
  }
}
