import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../milestones/providers/milestones_provider.dart';

class StreakNotifier extends StateNotifier<AsyncValue<StreakStateData>> {
  final AppDatabase _db;
  final Ref _ref;

  StreakNotifier(this._db, this._ref) : super(const AsyncValue.loading()) {
    updateStreakOnAppOpen();
  }

  String _localDateString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  String _currentMonthString(DateTime date) => DateFormat('yyyy-MM').format(date);

  Future<void> updateStreakOnAppOpen() async {
    try {
      final now = DateTime.now();
      final today = _localDateString(now);
      final currentMonth = _currentMonthString(now);

      var stateData = await _db.getStreakState();

      if (stateData == null) {
        final initial = StreakStatesCompanion.insert(
          id: const Value(1),
          currentStreak: const Value(0),
          longestStreak: const Value(0),
          lastLoggedDate: const Value(null),
          graceMissesUsed: const Value(0),
          graceMissesMonth: Value(currentMonth),
          freezeAvailable: const Value(2),
        );
        await _db.saveStreakState(initial);
        stateData = await _db.getStreakState();
      }

      if (stateData == null) return;

      int graceUsed = stateData.graceMissesUsed;
      String? graceMonth = stateData.graceMissesMonth;
      int freezeAvailable = stateData.freezeAvailable;
      int currentStreak = stateData.currentStreak;
      int longestStreak = stateData.longestStreak;
      String? lastLogged = stateData.lastLoggedDate;

      bool needsSave = false;

      // 1. Reset monthly grace if month changed
      if (graceMonth != currentMonth) {
        graceUsed = 0;
        graceMonth = currentMonth;
        freezeAvailable = 2;
        needsSave = true;
      }

      // 2. Check streak validity based on elapsed days
      if (lastLogged != null && lastLogged != today) {
        final lastDate = DateTime.tryParse(lastLogged);
        if (lastDate != null) {
          final todayDate = DateTime(now.year, now.month, now.day);
          final loggedDateOnly = DateTime(lastDate.year, lastDate.month, lastDate.day);
          final daysDiff = todayDate.difference(loggedDateOnly).inDays;

          if (daysDiff == 1) {
            // Logged yesterday, waiting for today's entry: streak intact!
          } else if (daysDiff > 1) {
            final missedDays = daysDiff - 1;
            if (missedDays == 1 && graceUsed < 2) {
              // Grace day applied!
              graceUsed += 1;
              freezeAvailable = (2 - graceUsed).clamp(0, 2);
              needsSave = true;
            } else {
              // Streak broken
              if (currentStreak != 0) {
                currentStreak = 0;
                needsSave = true;
              }
            }
          }
        }
      }

      if (needsSave) {
        await _db.saveStreakState(StreakStatesCompanion(
          id: const Value(1),
          currentStreak: Value(currentStreak),
          longestStreak: Value(longestStreak),
          lastLoggedDate: Value(lastLogged),
          graceMissesUsed: Value(graceUsed),
          graceMissesMonth: Value(graceMonth),
          freezeAvailable: Value(freezeAvailable),
        ));
        stateData = await _db.getStreakState();
      }

      if (stateData != null) {
        state = AsyncValue.data(stateData);
      }

      // Check evening reminder if after 6 PM
      _checkEveningReminder(stateData);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordTransactionForStreak(DateTime txDate) async {
    final now = DateTime.now();
    final today = _localDateString(now);
    final txDateStr = _localDateString(txDate);

    // Only same-day transactions advance streak
    if (txDateStr != today) return;

    var stateData = state.valueOrNull ?? await _db.getStreakState();
    if (stateData == null) {
      await updateStreakOnAppOpen();
      stateData = state.valueOrNull ?? await _db.getStreakState();
    }
    if (stateData == null) return;

    // Already counted today
    if (stateData.lastLoggedDate == today) return;

    final newStreak = stateData.currentStreak + 1;
    final newLongest = newStreak > stateData.longestStreak ? newStreak : stateData.longestStreak;

    final updatedCompanion = StreakStatesCompanion(
      id: const Value(1),
      currentStreak: Value(newStreak),
      longestStreak: Value(newLongest),
      lastLoggedDate: Value(today),
      graceMissesUsed: Value(stateData.graceMissesUsed),
      graceMissesMonth: Value(stateData.graceMissesMonth),
      freezeAvailable: Value(stateData.freezeAvailable),
    );

    await _db.saveStreakState(updatedCompanion);
    final fresh = await _db.getStreakState();
    if (fresh != null) {
      state = AsyncValue.data(fresh);
    }

    // Check milestones for streak
    if (newStreak == 7) {
      _ref.read(milestoneProvider.notifier).triggerMilestone('streak_7');
    } else if (newStreak == 30) {
      _ref.read(milestoneProvider.notifier).triggerMilestone('streak_30');
    } else if (newStreak == 100) {
      _ref.read(milestoneProvider.notifier).triggerMilestone('streak_100');
    }
  }

  Future<void> _checkEveningReminder(StreakStateData? stateData) async {
    if (stateData == null) return;
    final now = DateTime.now();
    if (now.hour < 18) return; // Only after 6 PM

    final today = _localDateString(now);
    if (stateData.lastLoggedDate == today) return; // Already logged today

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastReminderDate = prefs.getString('last_streak_reminder_date');
      if (lastReminderDate == today) return; // Already sent today

      await NotificationService().showStreakAtRiskReminder(
        currentStreak: stateData.currentStreak,
      );
      await prefs.setString('last_streak_reminder_date', today);
    } catch (_) {}
  }
}

final streakProvider =
    StateNotifierProvider<StreakNotifier, AsyncValue<StreakStateData>>((ref) {
  final db = ref.watch(databaseProvider);
  return StreakNotifier(db, ref);
});

