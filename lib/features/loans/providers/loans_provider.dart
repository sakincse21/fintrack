import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

/// Active loans with full details (Person + Account + paid amount)
final activeLoansProvider = StreamProvider<List<LoanWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLoansWithDetails(settled: false);
});

/// Settled loans with full details
final settledLoansProvider = StreamProvider<List<LoanWithDetails>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLoansWithDetails(settled: true);
});

/// Dashboard summary card data
final loanSummaryProvider = StreamProvider<LoanSummary>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchLoanSummary();
});

/// People list for person picker
final peopleListProvider = StreamProvider<List<Person>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllPeople();
});

/// Payments for a specific loan
final loanPaymentsProvider =
    StreamProvider.family<List<LoanPayment>, int>((ref, loanId) {
  final db = ref.watch(databaseProvider);
  return db.watchLoanPayments(loanId);
});

/// Single loan detail (refreshable)
final loanDetailProvider =
    FutureProvider.family<LoanWithDetails?, int>((ref, loanId) {
  final db = ref.watch(databaseProvider);
  return db.getLoanWithDetails(loanId);
});

/// Filter state for loans screen
enum LoanTypeFilter { all, lent, borrowed }

final loanTypeFilterProvider = StateProvider<LoanTypeFilter>((ref) => LoanTypeFilter.all);

