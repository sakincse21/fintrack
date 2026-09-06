import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

final selectedBudgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

final budgetsWithProgressProvider =
    StreamProvider<List<BudgetWithCategory>>((ref) {
  final db = ref.watch(databaseProvider);
  final selectedMonth = ref.watch(selectedBudgetMonthProvider);

  return db.watchBudgetsWithProgress(selectedMonth);
});

