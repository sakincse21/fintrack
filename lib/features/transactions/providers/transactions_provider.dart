import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/date_utils.dart';

enum TransactionSortBy {
  dateDesc('Date (Newest First)'),
  dateAsc('Date (Oldest First)'),
  amountDesc('Amount (Highest First)'),
  amountAsc('Amount (Lowest First)');

  final String label;
  const TransactionSortBy(this.label);
}

class TransactionFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final int? accountId;
  final Set<int> selectedCategoryIds; // Multi-select categories
  final Set<String> selectedTypes; // Multi-select types ('expense', 'income', 'transfer')
  final String searchQuery;
  final String? tag;
  final TransactionSortBy sortBy;

  const TransactionFilterState({
    this.dateRangeFilter = DateRangeFilter.allTime,
    this.customStartDate,
    this.customEndDate,
    this.accountId,
    this.selectedCategoryIds = const {},
    this.selectedTypes = const {},
    this.searchQuery = '',
    this.tag,
    this.sortBy = TransactionSortBy.dateDesc,
  });

  int? get categoryId => selectedCategoryIds.length == 1 ? selectedCategoryIds.first : null;
  String get type => selectedTypes.length == 1 ? selectedTypes.first : 'all';

  int get activeFiltersCount {
    int count = 0;
    if (selectedTypes.isNotEmpty) count += selectedTypes.length;
    if (dateRangeFilter != DateRangeFilter.allTime) count++;
    if (accountId != null) count++;
    if (selectedCategoryIds.isNotEmpty) count += selectedCategoryIds.length;
    if (tag != null && tag!.isNotEmpty) count++;
    if (searchQuery.isNotEmpty) count++;
    if (sortBy != TransactionSortBy.dateDesc) count++;
    return count;
  }

  TransactionFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    int? accountId,
    Set<int>? selectedCategoryIds,
    Set<String>? selectedTypes,
    String? searchQuery,
    String? tag,
    TransactionSortBy? sortBy,
    bool clearAccount = false,
    bool clearCategories = false,
    bool clearTypes = false,
    bool clearTag = false,
  }) {
    return TransactionFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      accountId: clearAccount ? null : (accountId ?? this.accountId),
      selectedCategoryIds: clearCategories ? const {} : (selectedCategoryIds ?? this.selectedCategoryIds),
      selectedTypes: clearTypes ? const {} : (selectedTypes ?? this.selectedTypes),
      searchQuery: searchQuery ?? this.searchQuery,
      tag: clearTag ? null : (tag ?? this.tag),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

class TransactionFilterNotifier extends StateNotifier<TransactionFilterState> {
  TransactionFilterNotifier() : super(const TransactionFilterState());

  void setDateFilter(DateRangeFilter filter, {DateTime? start, DateTime? end}) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: start,
      customEndDate: end,
    );
  }

  void setAccount(int? accountId) {
    if (accountId == null) {
      state = state.copyWith(clearAccount: true);
    } else {
      state = state.copyWith(accountId: accountId);
    }
  }

  void toggleCategory(int categoryId) {
    final current = Set<int>.from(state.selectedCategoryIds);
    if (current.contains(categoryId)) {
      current.remove(categoryId);
    } else {
      current.add(categoryId);
    }
    state = state.copyWith(selectedCategoryIds: current);
  }

  void setCategory(int? categoryId) {
    if (categoryId == null) {
      clearCategories();
    } else {
      state = state.copyWith(selectedCategoryIds: {categoryId});
    }
  }

  void clearCategories() {
    state = state.copyWith(clearCategories: true);
  }

  void toggleType(String type) {
    final current = Set<String>.from(state.selectedTypes);
    if (current.contains(type)) {
      current.remove(type);
    } else {
      current.add(type);
    }
    state = state.copyWith(selectedTypes: current);
  }

  void setType(String type) {
    if (type == 'all') {
      clearTypes();
    } else {
      state = state.copyWith(selectedTypes: {type});
    }
  }

  void clearTypes() {
    state = state.copyWith(clearTypes: true);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setTag(String? tag) {
    if (tag == null) {
      state = state.copyWith(clearTag: true);
    } else {
      state = state.copyWith(tag: tag);
    }
  }

  void setSortBy(TransactionSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void reset() {
    state = const TransactionFilterState();
  }
}

final transactionFilterProvider =
    StateNotifierProvider<TransactionFilterNotifier, TransactionFilterState>((ref) {
  return TransactionFilterNotifier();
});

final categoriesListFilterProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchCategories();
});

final filteredTransactionsProvider =
    StreamProvider<List<TransactionWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  final filter = ref.watch(transactionFilterProvider);

  final range = DateRange.fromFilter(
    filter.dateRangeFilter,
    customStart: filter.customStartDate,
    customEnd: filter.customEndDate,
  );

  return db
      .watchTransactionsFiltered(
        startDate: filter.dateRangeFilter != DateRangeFilter.allTime ? range.start : null,
        endDate: filter.dateRangeFilter != DateRangeFilter.allTime ? range.end : null,
        accountId: filter.accountId,
        categoryIds: filter.selectedCategoryIds,
        types: filter.selectedTypes,
        searchQuery: filter.searchQuery,
        tag: filter.tag,
      )
      .map((list) {
        final sorted = List<TransactionWithDetails>.from(list);
        switch (filter.sortBy) {
          case TransactionSortBy.dateDesc:
            sorted.sort((a, b) {
              final cmp = b.transaction.date.compareTo(a.transaction.date);
              if (cmp != 0) return cmp;
              return b.transaction.id.compareTo(a.transaction.id);
            });
            break;
          case TransactionSortBy.dateAsc:
            sorted.sort((a, b) {
              final cmp = a.transaction.date.compareTo(b.transaction.date);
              if (cmp != 0) return cmp;
              return a.transaction.id.compareTo(b.transaction.id);
            });
            break;
          case TransactionSortBy.amountDesc:
            sorted.sort((a, b) => b.transaction.amountCents.compareTo(a.transaction.amountCents));
            break;
          case TransactionSortBy.amountAsc:
            sorted.sort((a, b) => a.transaction.amountCents.compareTo(b.transaction.amountCents));
            break;
        }
        return sorted;
      });
});

final recentTransactionsProvider =
    StreamProvider<List<TransactionWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentTransactions(limit: 15);
});
