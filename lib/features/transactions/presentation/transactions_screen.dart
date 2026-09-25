import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/csv_json_export_import.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../quick_add/presentation/quick_add_sheet.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/transactions_provider.dart';
import 'widgets/transaction_detail_dialog.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  bool _showFilterBar = false;
  bool _filterRecurringOnly = false;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        ref.read(transactionFilterProvider.notifier).setSearch(query);
      }
    });
  }

  Future<void> _exportFilteredTransactions(List<TransactionWithDetails> items) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export in current filter.')),
      );
      return;
    }

    final csvItems = items.map((i) {
      final tx = i.transaction;
      return CsvExportData(
        date: AppDateUtils.formatFullDate(tx.date),
        account: i.account.name,
        category: i.category?.name ?? (tx.type == 'transfer' ? 'Transfer' : 'Expense'),
        type: tx.type,
        amount: tx.amountCents / 100.0,
        note: tx.note,
        tags: tx.tagIds,
      );
    }).toList();

    final csvString = CsvJsonExporter.transactionsToCsv(csvItems);
    await Share.share(
      csvString,
      subject: 'FinTrack_Transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final filterNotifier = ref.read(transactionFilterProvider.notifier);
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsListProvider);
    final categoriesAsync = ref.watch(categoriesListFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeFilterCount = filter.activeFiltersCount;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24)),
        actions: [
          transactionsAsync.maybeWhen(
            data: (items) => Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length} records',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(_showFilterBar ? Icons.tune_rounded : Icons.filter_list_rounded, size: 21),
                tooltip: 'Filter Activity',
                color: _showFilterBar || activeFilterCount > 0 ? AppColors.primary : null,
                onPressed: () => setState(() => _showFilterBar = !_showFilterBar),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
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
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, size: 21),
            tooltip: 'Export CSV',
            onPressed: () {
              transactionsAsync.whenData((items) => _exportFilteredTransactions(items));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Rounded Pill Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search merchants, notes, amounts',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // Quick Filter Pills (All, Expenses, Income, Recurring)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildQuickFilterPill(
                    label: 'All',
                    isSelected: filter.selectedTypes.isEmpty && !_filterRecurringOnly,
                    onTap: () {
                      setState(() => _filterRecurringOnly = false);
                      filterNotifier.clearTypes();
                    },
                  ),
                  _buildQuickFilterPill(
                    label: 'Expenses',
                    isSelected: filter.selectedTypes.length == 1 &&
                        filter.selectedTypes.contains('expense') &&
                        !_filterRecurringOnly,
                    onTap: () {
                      setState(() => _filterRecurringOnly = false);
                      filterNotifier.setType('expense');
                    },
                  ),
                  _buildQuickFilterPill(
                    label: 'Income',
                    isSelected: filter.selectedTypes.length == 1 &&
                        filter.selectedTypes.contains('income') &&
                        !_filterRecurringOnly,
                    onTap: () {
                      setState(() => _filterRecurringOnly = false);
                      filterNotifier.setType('income');
                    },
                  ),
                  _buildQuickFilterPill(
                    label: 'Recurring',
                    isSelected: _filterRecurringOnly,
                    onTap: () {
                      setState(() {
                        _filterRecurringOnly = !_filterRecurringOnly;
                        if (_filterRecurringOnly) {
                          filterNotifier.clearTypes();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Active Filter Chips Strip (When filters are active and bar is collapsed)
          if (activeFilterCount > 0 && !_showFilterBar) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Multi-select types badges
                  ...filter.selectedTypes.map(
                    (t) => _buildActiveBadge(
                      label: t.toUpperCase(),
                      onDelete: () => filterNotifier.toggleType(t),
                    ),
                  ),

                  // Date range badge
                  if (filter.dateRangeFilter != DateRangeFilter.allTime)
                    _buildActiveBadge(
                      label: filter.dateRangeFilter.name,
                      onDelete: () => filterNotifier.setDateFilter(DateRangeFilter.allTime),
                    ),

                  // Multi-select categories badges
                  ...filter.selectedCategoryIds.map(
                    (catId) => categoriesAsync.when(
                      data: (cats) {
                        final cat = cats.where((c) => c.id == catId).firstOrNull;
                        return _buildActiveBadge(
                          label: cat?.name ?? 'Category #$catId',
                          onDelete: () => filterNotifier.toggleCategory(catId),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),

                  // Account badge
                  if (filter.accountId != null)
                    accountsAsync.when(
                      data: (accs) {
                        final acc = accs.where((a) => a.id == filter.accountId).firstOrNull;
                        return _buildActiveBadge(
                          label: 'Account: ${acc?.name ?? filter.accountId}',
                          onDelete: () => filterNotifier.setAccount(null),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                  // Sort badge
                  if (filter.sortBy != TransactionSortBy.dateDesc)
                    _buildActiveBadge(
                      label: filter.sortBy.label,
                      onDelete: () => filterNotifier.setSortBy(TransactionSortBy.dateDesc),
                    ),

                  InkWell(
                    onTap: () => filterNotifier.reset(),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          // Collapsible Comprehensive Multi-Select Filter Bar
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
                  // 1. Transaction Types (Multi-Select)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'TYPES',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                          ),
                          if (filter.selectedTypes.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filter.selectedTypes.length} selected',
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
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildMultiFilterPill(
                          label: 'All Types',
                          isSelected: filter.selectedTypes.isEmpty,
                          onTap: () => filterNotifier.clearTypes(),
                        ),
                        const SizedBox(width: 8),
                        _buildMultiFilterPill(
                          label: 'Expense',
                          isSelected: filter.selectedTypes.contains('expense'),
                          onTap: () => filterNotifier.toggleType('expense'),
                          color: AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        _buildMultiFilterPill(
                          label: 'Income',
                          isSelected: filter.selectedTypes.contains('income'),
                          onTap: () => filterNotifier.toggleType('income'),
                          color: AppColors.income,
                        ),
                        const SizedBox(width: 8),
                        _buildMultiFilterPill(
                          label: 'Transfer',
                          isSelected: filter.selectedTypes.contains('transfer'),
                          onTap: () => filterNotifier.toggleType('transfer'),
                          color: AppColors.transfer,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Categories (Multi-Select)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'CATEGORIES',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
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
                          child: const Text('Clear Categories', style: TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    data: (categories) {
                      final filteredCategories = filter.selectedTypes.length == 1
                          ? categories.where((c) => c.type == filter.selectedTypes.first).toList()
                          : categories;

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
                            ...filteredCategories.map((cat) {
                              final isSelected = filter.selectedCategoryIds.contains(cat.id);

                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => filterNotifier.toggleCategory(cat.id),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.primary
                                          : isDark
                                              ? AppColors.darkSurfaceElevated
                                              : AppColors.lightSurfaceElevated,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : isDark
                                                ? AppColors.darkBorder
                                                : AppColors.lightBorder,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isSelected) ...[
                                          const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                          const SizedBox(width: 5),
                                        ] else ...[
                                          Icon(
                                            IconHelper.getIcon(cat.icon),
                                            size: 15,
                                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                          ),
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

                  // 3. Date Range Filter Pills
                  const Text(
                    'DATE RANGE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All Time', filter.dateRangeFilter == DateRangeFilter.allTime, () => filterNotifier.setDateFilter(DateRangeFilter.allTime)),
                        const SizedBox(width: 8),
                        _buildFilterPill('This Month', filter.dateRangeFilter == DateRangeFilter.thisMonth, () => filterNotifier.setDateFilter(DateRangeFilter.thisMonth)),
                        const SizedBox(width: 8),
                        _buildFilterPill('Last Month', filter.dateRangeFilter == DateRangeFilter.lastMonth, () => filterNotifier.setDateFilter(DateRangeFilter.lastMonth)),
                        const SizedBox(width: 8),
                        _buildFilterPill('Last 90 Days', filter.dateRangeFilter == DateRangeFilter.last90Days, () => filterNotifier.setDateFilter(DateRangeFilter.last90Days)),
                        const SizedBox(width: 8),
                        _buildFilterPill('This Year', filter.dateRangeFilter == DateRangeFilter.thisYear, () => filterNotifier.setDateFilter(DateRangeFilter.thisYear)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Account & Sort Row
                  Row(
                    children: [
                      // Account Selector Dropdown
                      Expanded(
                        child: accountsAsync.when(
                          data: (rawAccounts) {
                            final seenIds = <int>{};
                            final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                            final selectedValue = accounts.any((a) => a.id == filter.accountId) ? filter.accountId : null;

                            return DropdownButtonFormField<int?>(
                              key: ValueKey('filter_acc_$selectedValue'),
                              initialValue: selectedValue,
                              decoration: const InputDecoration(
                                labelText: 'Account',
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
                      ),
                      const SizedBox(width: 12),

                      // Sort By Dropdown
                      Expanded(
                        child: DropdownButtonFormField<TransactionSortBy>(
                          initialValue: filter.sortBy,
                          decoration: const InputDecoration(
                            labelText: 'Sort By',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: TransactionSortBy.values.map((sort) {
                            return DropdownMenuItem(
                              value: sort,
                              child: Text(sort.label, style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (sort) {
                            if (sort != null) filterNotifier.setSortBy(sort);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Filtered Summary Header
          transactionsAsync.when(
            data: (items) {
              final income = items.where((i) => i.transaction.type == 'income').fold<int>(0, (sum, i) => sum + i.transaction.amountCents);
              final expense = items.where((i) => i.transaction.type == 'expense').fold<int>(0, (sum, i) => sum + i.transaction.amountCents);
              final net = income - expense;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${items.length} records',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '+${CurrencyFormatter.formatCents(income, symbol: currency.symbol)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.income),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '-${CurrencyFormatter.formatCents(expense, symbol: currency.symbol)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.expense),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${CurrencyFormatter.formatCents(net, symbol: currency.symbol, showSign: true)})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: net >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Transactions List Grouped by Date
          Expanded(
            child: transactionsAsync.when(
              data: (rawItems) {
                final items = _filterRecurringOnly
                    ? rawItems
                        .where((i) =>
                            i.transaction.isRecurring || i.transaction.recurringId != null)
                        .toList()
                    : rawItems;

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 52, color: Colors.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 14),
                        const Text('No transactions match this filter',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() => _filterRecurringOnly = false);
                            filterNotifier.reset();
                          },
                          child: const Text('Reset All Filters',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }

                // Group transactions by calendar day
                final grouped = <String, List<TransactionWithDetails>>{};
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final yesterday = today.subtract(const Duration(days: 1));

                for (final item in items) {
                  final d = item.transaction.date;
                  final itemDate = DateTime(d.year, d.month, d.day);
                  String dateHeader;
                  if (itemDate.isAtSameMomentAs(today)) {
                    dateHeader = 'TODAY';
                  } else if (itemDate.isAtSameMomentAs(yesterday)) {
                    dateHeader = 'YESTERDAY';
                  } else {
                    dateHeader = DateFormat('EEE, MMM d').format(d).toUpperCase();
                  }
                  grouped.putIfAbsent(dateHeader, () => []).add(item);
                }

                final dateHeaders = grouped.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: dateHeaders.length,
                  itemBuilder: (context, groupIndex) {
                    final header = dateHeaders[groupIndex];
                    final groupItems = grouped[header]!;

                    int dailyTotalCents = 0;
                    for (final item in groupItems) {
                      if (item.transaction.type == 'income') {
                        dailyTotalCents += item.transaction.amountCents;
                      } else if (item.transaction.type == 'expense') {
                        dailyTotalCents -= item.transaction.amountCents;
                      }
                    }

                    final isPositiveDaily = dailyTotalCents > 0;
                    final dailyTotalFormatted = dailyTotalCents == 0
                        ? '${currency.symbol}0.00'
                        : isPositiveDaily
                            ? '+${CurrencyFormatter.formatCents(dailyTotalCents, symbol: currency.symbol)}'
                            : '-${CurrencyFormatter.formatCents(dailyTotalCents.abs(), symbol: currency.symbol)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Section Header
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  header,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  dailyTotalFormatted,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isPositiveDaily
                                        ? AppColors.income
                                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Grouped Rounded Card
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < groupItems.length; i++) ...[
                                  if (i > 0)
                                    Divider(
                                      height: 1,
                                      indent: 68,
                                      endIndent: 16,
                                      color: isDark
                                          ? AppColors.darkBorderSubtle
                                          : AppColors.lightBorder,
                                    ),
                                  _buildTransactionTile(
                                    groupItems[i],
                                    currency: currency,
                                    isDark: isDark,
                                    isFirst: i == 0,
                                    isLast: i == groupItems.length - 1,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => QuickAddSheet.show(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildTransactionTile(
    TransactionWithDetails item, {
    required CurrencyInfo currency,
    required bool isDark,
    required bool isFirst,
    required bool isLast,
  }) {
    final tx = item.transaction;
    final cat = item.category;
    final account = item.account;
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final isRepeating = tx.isRecurring || tx.recurringId != null;

    final amountColor = isIncome
        ? AppColors.income
        : isTransfer
            ? AppColors.transfer
            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    final db = ref.read(databaseProvider);

    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('tx_${tx.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppColors.expense.withValues(alpha: 0.85),
            borderRadius: BorderRadius.vertical(
              top: isFirst ? const Radius.circular(20) : Radius.zero,
              bottom: isLast ? const Radius.circular(20) : Radius.zero,
            ),
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
        ),
        onDismissed: (_) async {
          await db.softDeleteTransaction(tx.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Transaction deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => db.restoreTransaction(tx.id),
                ),
              ),
            );
          }
        },
        child: InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => TransactionDetailDialog(item: item),
            );
          },
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Unboxed Slim Material Icon
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      isTransfer
                          ? Icons.swap_horiz_rounded
                          : IconHelper.getIcon(cat?.icon ??
                              (isIncome ? 'attach_money' : 'receipt_long')),
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title & Subtitle with optional REPEATS badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tx.note.isNotEmpty
                                  ? tx.note
                                  : (isTransfer ? 'Account Transfer' : (cat?.name ?? 'General')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                          if (isRepeating) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'REPEATS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${cat?.name ?? (isTransfer ? 'Transfer' : 'General')} · ${account.name} · ${DateFormat('MMM d, h:mm a').format(tx.date)}${isTransfer && tx.feeCents > 0 ? ' · Fee: ${CurrencyFormatter.formatCents(tx.feeCents, symbol: currency.symbol)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Trailing Amount & Time
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : isTransfer ? '' : '-'}${CurrencyFormatter.formatCents(tx.amountCents, symbol: currency.symbol)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: amountColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('h:mm a').format(tx.date),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isSelected
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? AppColors.darkSurface : AppColors.lightSurface);
    final text = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final border = isSelected
        ? Colors.transparent
        : (isDark ? AppColors.darkBorder : AppColors.lightBorder);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: text,
            ),
          ),
        ),
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
            child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
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
            if (isSelected && label != 'All Types' && label != 'All Categories') ...[
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
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

  Widget _buildFilterPill(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    final activeColor = color ?? AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : isDark
                  ? AppColors.darkSurfaceElevated
                  : AppColors.lightSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }
}
