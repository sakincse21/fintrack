import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

class GoalCalculation {
  final Goal goal;

  GoalCalculation(this.goal);

  double get progress => goal.targetAmountCents > 0
      ? (goal.currentAmountCents / goal.targetAmountCents).clamp(0.0, 1.0)
      : 0.0;

  int get remainingCents =>
      (goal.targetAmountCents - goal.currentAmountCents).clamp(0, goal.targetAmountCents);

  bool get isCompleted => goal.currentAmountCents >= goal.targetAmountCents;

  int get daysRemaining {
    final diff = goal.targetDate.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  int get monthsRemaining {
    final now = DateTime.now();
    final months = (goal.targetDate.year - now.year) * 12 +
        (goal.targetDate.month - now.month);
    return months > 0 ? months : 1;
  }

  int get suggestedMonthlyContributionCents {
    if (isCompleted || remainingCents <= 0) return 0;
    final m = monthsRemaining;
    return (remainingCents / m).round();
  }
}

final goalsListProvider = StreamProvider<List<GoalCalculation>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllGoals().map((goals) {
    return goals.map((g) => GoalCalculation(g)).toList();
  });
});

