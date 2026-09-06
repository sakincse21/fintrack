import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../transactions/providers/transactions_provider.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedCategoryTouchedIndex = -1;
  bool _showFilterBar = false;

  void _shareReportSummary(FullAnalyticsReport report, String symbol) {
    final rangeText = report.dateRange.label;
    final incomeStr = CurrencyFormatter.formatCents(report.totalIncomeCents, symbol: symbol);
    final expenseStr = CurrencyFormatter.formatCents(report.totalExpenseCents, symbol: symbol);
    final netStr = CurrencyFormatter.formatCents(report.netSavingsCents, symbol: symbol);

    final buffer = StringBuffer();
    buffer.writeln('📊 FinTrack VittaFinance Analytics ($rangeText)');
    buffer.writeln('-----------------------------------');
    buffer.writeln('💰 Total Income: $incomeStr');
    buffer.writeln('💸 Total Expenses: $expenseStr');
    buffer.writeln('📈 Net Savings: $netStr (${report.overallSavingsRate.toStringAsFixed(1)}% savings rate)');
    buffer.writeln('');

    if (report.categoryBreakdowns.isNotEmpty) {
      buffer.writeln('🏷️ Spending Overview:');
      for (final cat in report.categoryBreakdowns.take(5)) {
        final catAmt = CurrencyFormatter.formatCents(cat.totalCents, symbol: symbol);
        buffer.writeln(' • ${cat.category.name}: $catAmt (${(cat.percentage * 100).toStringAsFixed(1)}%)');
      }
      buffer.writeln('');
    }

    if (report.topMerchants.isNotEmpty) {
      buffer.writeln('🏪 Top Places / Merchants:');
      for (final m in report.topMerchants.take(5)) {
        final mAmt = CurrencyFormatter.formatCents(m.totalCents, symbol: symbol);
        buffer.writeln(' • ${m.merchant}: $mAmt (${m.count} transactions)');
      }
    }

    Share.share(buffer.toString(), subject: 'FinTrack Report - $rangeText');
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final filter = ref.read(reportFilterProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: filter.customStart != null && filter.customEnd != null
          ? DateTimeRange(start: filter.customStart!, end: filter.customEnd!)
          : DateTimeRange(start: AppDateUtils.startOfMonth(now), end: AppDateUtils.endOfMonth(now)),
    );

    if (picked != null) {
      ref.read(reportFilterProvider.notifier).setFilter(
        DateRangeFilter.custom,
        start: picked.start,
        end: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(fullAnalyticsProvider);
    final filter = ref.watch(reportFilterProvider);
    final filterNotifier = ref.read(reportFilterProvider.notifier);
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesListFilterProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFilterCount = filter.activeFiltersCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Your spending overview',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Filter Toggle Button with Active Count Badge
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _showFilterBar || activeFilterCount > 0
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showFilterBar || activeFilterCount > 0
                          ? AppColors.primary
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    _showFilterBar ? LucideIcons.listFilter : LucideIcons.filter,
                    size: 18,
                    color: _showFilterBar || activeFilterCount > 0
                        ? AppColors.primary
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                tooltip: 'Filter Analytics',
                onPressed: () => setState(() => _showFilterBar = !_showFilterBar),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$activeFilterCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),

          // Share Report Button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
                ),
              ),
              child: const Icon(LucideIcons.share2, size: 18),
            ),
            tooltip: 'Share Report',
            onPressed: () {
              reportAsync.whenData((rep) => _shareReportSummary(rep, currency.symbol));
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          // Active Filter Chips Strip (When filters are active and bar is collapsed)
          if (activeFilterCount > 0 && !_showFilterBar) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Type badge
                  if (filter.selectedType != 'all')
                    _buildActiveBadge(
                      label: filter.selectedType == 'expense' ? 'Expense Only' : 'Income Only',
                      onDelete: () => filterNotifier.setType('all'),
                    ),

                  // Account badge
                  if (filter.accountId != null)
                    accountsAsync.when(
                      data: (accounts) {
                        final acc = accounts.where((a) => a.id == filter.accountId).firstOrNull;
                        if (acc == null) return const SizedBox.shrink();
                        return _buildActiveBadge(
                          label: acc.name,
                          onDelete: () => filterNotifier.setAccount(null),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                  // Category badges
                  if (filter.selectedCategoryIds.isNotEmpty)
                    categoriesAsync.when(
                      data: (cats) {
                        final catMap = {for (var c in cats) c.id: c};
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: filter.selectedCategoryIds.map((cid) {
                            final cat = catMap[cid];
                            return _buildActiveBadge(
                              label: cat?.name ?? 'Category',
                              onDelete: () => filterNotifier.toggleCategory(cid),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                  // Custom date badge
                  if (filter.dateRangeFilter == DateRangeFilter.custom && filter.customStart != null && filter.customEnd != null)
                    _buildActiveBadge(
                      label: '${DateFormat('dd MMM').format(filter.customStart!)} - ${DateFormat('dd MMM').format(filter.customEnd!)}',
                      onDelete: () => filterNotifier.setFilter(DateRangeFilter.thisMonth),
                    )
                  else if (filter.dateRangeFilter != DateRangeFilter.thisMonth)
                    _buildActiveBadge(
                      label: filter.dateRangeFilter.name,
                      onDelete: () => filterNotifier.setFilter(DateRangeFilter.thisMonth),
                    ),

                  // Clear All
                  InkWell(
                    onTap: () => filterNotifier.reset(),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Collapsible Comprehensive Filter Bar
          if (_showFilterBar) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'ANALYTICS FILTERS',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          if (activeFilterCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$activeFilterCount active',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (activeFilterCount > 0)
                        InkWell(
                          onTap: () => filterNotifier.reset(),
                          child: const Text('Reset All', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Transaction Type
                  const Text(
                    'FLOW TYPE',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMultiFilterPill(
                          label: 'All Flow',
                          isSelected: filter.selectedType == 'all',
                          onTap: () => filterNotifier.setType('all'),
                        ),
                        const SizedBox(width: 8),
                        _buildMultiFilterPill(
                          label: 'Expense Only',
                          isSelected: filter.selectedType == 'expense',
                          onTap: () => filterNotifier.setType(filter.selectedType == 'expense' ? 'all' : 'expense'),
                          color: AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        _buildMultiFilterPill(
                          label: 'Income Only',
                          isSelected: filter.selectedType == 'income',
                          onTap: () => filterNotifier.setType(filter.selectedType == 'income' ? 'all' : 'income'),
                          color: AppColors.income,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Account Selector
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACCOUNT',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            accountsAsync.when(
                              data: (rawAccounts) {
                                final seenIds = <int>{};
                                final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                                final selectedValue = accounts.any((a) => a.id == filter.accountId) ? filter.accountId : null;

                                return DropdownButtonFormField<int?>(
                                  key: ValueKey('report_filter_acc_$selectedValue'),
                                  initialValue: selectedValue,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: null, child: Text('All Accounts', style: TextStyle(fontSize: 13))),
                                    ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, style: const TextStyle(fontSize: 13)))),
                                  ],
                                  onChanged: (id) => filterNotifier.setAccount(id),
                                );
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Category Multi-Select
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'CATEGORIES',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          if (filter.selectedCategoryIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filter.selectedCategoryIds.length} selected',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (filter.selectedCategoryIds.isNotEmpty)
                        InkWell(
                          onTap: () => filterNotifier.clearCategories(),
                          child: const Text('Clear', style: TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  categoriesAsync.when(
                    data: (cats) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMultiFilterPill(
                              label: 'All Categories',
                              isSelected: filter.selectedCategoryIds.isEmpty,
                              onTap: () => filterNotifier.clearCategories(),
                            ),
                            const SizedBox(width: 8),
                            ...cats.map((cat) {
                              final isSelected = filter.selectedCategoryIds.contains(cat.id);
                              final catColor = Color(cat.colorValue);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => filterNotifier.toggleCategory(cat.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primary : (isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(LucideIcons.check, size: 14, color: Colors.white),
                                          const SizedBox(width: 5),
                                        ] else ...[
                                          Icon(IconHelper.getIcon(cat.icon), size: 15, color: catColor),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),

                  // 4. Custom Date Range Option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CUSTOM DATE RANGE',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      TextButton.icon(
                        onPressed: () => _selectCustomDateRange(context),
                        icon: const Icon(LucideIcons.calendar, size: 15),
                        label: Text(
                          filter.dateRangeFilter == DateRangeFilter.custom && filter.customStart != null
                              ? '${DateFormat('dd MMM').format(filter.customStart!)} - ${DateFormat('dd MMM').format(filter.customEnd!)}'
                              : 'Select Dates',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Month / Timeframe Range Quick Filter Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMonthPill('This Month', DateRangeFilter.thisMonth, filter.dateRangeFilter, filterNotifier, isDark),
                  const SizedBox(width: 8),
                  _buildMonthPill('Last Month', DateRangeFilter.lastMonth, filter.dateRangeFilter, filterNotifier, isDark),
                  const SizedBox(width: 8),
                  _buildMonthPill('Last 90 Days', DateRangeFilter.last90Days, filter.dateRangeFilter, filterNotifier, isDark),
                  const SizedBox(width: 8),
                  _buildMonthPill('This Year', DateRangeFilter.thisYear, filter.dateRangeFilter, filterNotifier, isDark),
                  const SizedBox(width: 8),
                  _buildMonthPill('All Time', DateRangeFilter.allTime, filter.dateRangeFilter, filterNotifier, isDark),
                  const SizedBox(width: 8),
                  _buildCustomRangePill(filter, isDark),
                ],
              ),
            ),
          ),

          Expanded(
            child: reportAsync.when(
              data: (report) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
                  children: [
                    // 1. Monthly Overview Donut Chart & Side Legend (Matching VittaFinance)
                    _buildVittaMonthlyOverview(report, currency.symbol, isDark, filter),
                    const SizedBox(height: 18),

                    // 2. Spending Trend Bar Chart (Monthly breakdown)
                    _buildVittaBarChart(report, currency.symbol, isDark, filter),
                    const SizedBox(height: 18),

                    // 3. Category Breakdown Cards (with transaction counts)
                    _buildVittaCategoryList(report, currency.symbol, isDark),
                    const SizedBox(height: 18),

                    // 4. Cashflow Summary Card
                    _buildSummaryCard(report, currency.symbol, isDark),
                    const SizedBox(height: 18),

                    // 5. Top Places & Merchants
                    if (report.topMerchants.isNotEmpty) ...[
                      _buildTopMerchantsCard(report.topMerchants, currency.symbol, isDark),
                      const SizedBox(height: 18),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error generating statistics: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBadge({required String label, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(8),
            child: const Icon(LucideIcons.x, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.lightSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? activeColor
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected && label != 'All Flow' && label != 'All Categories') ...[
              const Icon(LucideIcons.check, size: 13, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRangePill(ReportFilterState filter, bool isDark) {
    final isCustom = filter.dateRangeFilter == DateRangeFilter.custom &&
        filter.customStart != null &&
        filter.customEnd != null;

    final label = isCustom
        ? '${DateFormat('dd MMM').format(filter.customStart!)} - ${DateFormat('dd MMM').format(filter.customEnd!)}'
        : 'Custom';

    return InkWell(
      onTap: () => _selectCustomDateRange(context),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isCustom
              ? AppColors.primary
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCustom
                ? AppColors.primary
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: 1.0,
          ),
          boxShadow: isCustom
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.calendar,
              size: 14,
              color: isCustom
                  ? Colors.white
                  : isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isCustom ? FontWeight.w800 : FontWeight.w600,
                color: isCustom
                    ? Colors.white
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthPill(
    String label,
    DateRangeFilter filterVal,
    DateRangeFilter currentVal,
    ReportFilterNotifier notifier,
    bool isDark,
  ) {
    final isSelected = filterVal == currentVal;

    return InkWell(
      onTap: () => notifier.setFilter(filterVal),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isDark
                  ? AppColors.darkSurface
                  : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  // 1. VittaFinance Monthly Overview Donut + Side Legend Card
  Widget _buildVittaMonthlyOverview(FullAnalyticsReport report, String symbol, bool isDark, ReportFilterState filter) {
    final isIncomeOnly = filter.selectedType == 'income';
    final totalAmount = isIncomeOnly ? report.totalIncomeCents : report.totalExpenseCents;
    final breakdowns = report.categoryBreakdowns;
    final title = isIncomeOnly ? 'Income Overview' : (filter.selectedType == 'expense' ? 'Expense Overview' : 'Monthly Overview');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17.5,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          if (breakdowns.isEmpty || totalAmount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(LucideIcons.chartPie, size: 44, color: Colors.grey.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),
                    Text(
                      'No ${isIncomeOnly ? 'income' : 'expense'} records for this period',
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                // Donut Chart on Left
                SizedBox(
                  width: 146,
                  height: 146,
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
                                    _selectedCategoryTouchedIndex = -1;
                                    return;
                                  }
                                  _selectedCategoryTouchedIndex =
                                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                                });
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            sectionsSpace: 3.5,
                            centerSpaceRadius: 44,
                            sections: _buildVittaPieSections(breakdowns),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isIncomeOnly ? 'Income' : 'Total',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatCompact(totalAmount, symbol: symbol),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 22),

                // Percentage Legend on Right (Matching Vitta: ● Category % )
                Expanded(
                  child: Column(
                    children: breakdowns.take(5).map((item) {
                      final catColor = Color(item.category.colorValue);
                      final pct = (item.percentage * 100).toStringAsFixed(0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                item.category.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
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

  List<PieChartSectionData> _buildVittaPieSections(List<CategoryBreakdownItem> list) {
    final sections = <PieChartSectionData>[];
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      final isTouched = i == _selectedCategoryTouchedIndex;
      final radius = isTouched ? 26.0 : 20.0;

      sections.add(
        PieChartSectionData(
          color: Color(item.category.colorValue),
          value: item.totalCents.toDouble(),
          title: '',
          radius: radius,
        ),
      );
    }
    return sections;
  }

  // 2. VittaFinance Spending Bar Trend Chart
  Widget _buildVittaBarChart(FullAnalyticsReport report, String symbol, bool isDark, ReportFilterState filter) {
    final trends = report.monthlyTrends;
    if (trends.isEmpty) return const SizedBox.shrink();

    final isIncomeOnly = filter.selectedType == 'income';
    final maxVal = trends.fold<int>(1, (max, t) {
      final amt = isIncomeOnly ? t.incomeCents : t.expenseCents;
      return amt > max ? amt : max;
    });

    final title = isIncomeOnly ? 'Income Trend' : 'Spending Trend';
    final primaryBarColor = isIncomeOnly ? AppColors.income : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
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
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17.5,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Monthly', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 22),

          SizedBox(
            height: 150,
            child: RepaintBoundary(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxVal / 100.0) * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => isDark ? AppColors.darkSurfaceElevated : Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = trends[groupIndex];
                        final monthName = DateFormat('MMM').format(item.monthDate);
                        final amtVal = isIncomeOnly ? item.incomeCents : item.expenseCents;
                        final amt = CurrencyFormatter.formatCents(amtVal, symbol: symbol);
                        return BarTooltipItem(
                          '$monthName\n$amt',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < trends.length) {
                            final item = trends[idx];
                            final isCurrent = idx == trends.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                DateFormat('MMM').format(item.monthDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                  color: isCurrent
                                      ? primaryBarColor
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: trends.asMap().entries.map((e) {
                    final idx = e.key;
                    final item = e.value;
                    final isLatest = idx == trends.length - 1;
                    final amtVal = isIncomeOnly ? item.incomeCents : item.expenseCents;

                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: (amtVal / 100.0).clamp(0.1, double.infinity),
                          color: isLatest
                              ? primaryBarColor
                              : isDark
                                  ? const Color(0xFF38322D)
                                  : const Color(0xFFEBE2D5),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. VittaFinance Category Breakdown Cards
  Widget _buildVittaCategoryList(FullAnalyticsReport report, String symbol, bool isDark) {
    final list = report.categoryBreakdowns;
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOP CATEGORIES',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.8,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 12),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.take(6).length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = list[index];
            final cat = item.category;
            final catColor = Color(cat.colorValue);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pastel Icon Avatar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(IconHelper.getIcon(cat.icon), color: catColor, size: 20),
                  ),
                  const SizedBox(width: 16),

                  // Name & Transaction Count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item.transactionCount} transactions • ${(item.percentage * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Amount
                  Text(
                    CurrencyFormatter.formatCents(item.totalCents, symbol: symbol),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // 4. Cash Flow Summary Overview
  Widget _buildSummaryCard(FullAnalyticsReport report, String symbol, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryCol('Income', '+${CurrencyFormatter.formatCents(report.totalIncomeCents, symbol: symbol)}', AppColors.income),
          Container(width: 1, height: 40, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          _buildSummaryCol('Expenses', '-${CurrencyFormatter.formatCents(report.totalExpenseCents, symbol: symbol)}', AppColors.expense),
          Container(width: 1, height: 40, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          _buildSummaryCol(
            'Savings Rate',
            '${report.overallSavingsRate.toStringAsFixed(1)}%',
            report.overallSavingsRate >= 0 ? AppColors.income : AppColors.expense,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  // 5. Top Merchants Card
  Widget _buildTopMerchantsCard(List<MerchantRankItem> merchants, String symbol, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Places & Merchants', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 14),
          ...merchants.take(5).map((m) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.store, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.merchant, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        Text('${m.count} transactions', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatCents(m.totalCents, symbol: symbol),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
