import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

class MilestoneInfo {
  final String key;
  final String title;
  final String description;
  final String iconType; // 'flame', 'trophy', 'shield', 'sparkles'

  const MilestoneInfo({
    required this.key,
    required this.title,
    required this.description,
    required this.iconType,
  });
}

const Map<String, MilestoneInfo> kKnownMilestones = {
  'first_transaction': MilestoneInfo(
    key: 'first_transaction',
    title: 'First Step Taken!',
    description: 'You logged your very first transaction in FinTrack. Welcome on board!',
    iconType: 'sparkles',
  ),
  'streak_7': MilestoneInfo(
    key: 'streak_7',
    title: '7 Days and Counting!',
    description: 'One full week of consistent financial tracking. Momentum is building!',
    iconType: 'flame',
  ),
  'streak_30': MilestoneInfo(
    key: 'streak_30',
    title: '30-Day Master!',
    description: 'A whole month of daily tracking! Financial clarity is now a habit.',
    iconType: 'flame',
  ),
  'streak_100': MilestoneInfo(
    key: 'streak_100',
    title: 'Centurion: 100 Days!',
    description: 'Incredible dedication! You are among the top disciplined finance trackers.',
    iconType: 'flame',
  ),
  'first_goal': MilestoneInfo(
    key: 'first_goal',
    title: 'Goal Achieved!',
    description: 'Congratulations! You reached 100% of your savings goal.',
    iconType: 'trophy',
  ),
  'budget_under_month_1': MilestoneInfo(
    key: 'budget_under_month_1',
    title: 'Under Budget Champion!',
    description: 'You finished the month without exceeding your budget limits. Well done!',
    iconType: 'shield',
  ),
};

class MilestoneState {
  final List<String> achievedKeys;
  final MilestoneInfo? pendingCelebration;

  const MilestoneState({
    this.achievedKeys = const [],
    this.pendingCelebration,
  });

  MilestoneState copyWith({
    List<String>? achievedKeys,
    MilestoneInfo? pendingCelebration,
    bool clearCelebration = false,
  }) {
    return MilestoneState(
      achievedKeys: achievedKeys ?? this.achievedKeys,
      pendingCelebration:
          clearCelebration ? null : (pendingCelebration ?? this.pendingCelebration),
    );
  }
}

class MilestoneNotifier extends StateNotifier<MilestoneState> {
  final AppDatabase _db;

  MilestoneNotifier(this._db) : super(const MilestoneState()) {
    _loadAchieved();
  }

  Future<void> _loadAchieved() async {
    final keys = await _db.getAchievedMilestoneKeys();
    state = state.copyWith(achievedKeys: keys);
  }

  /// Triggers a milestone check. If not achieved before, records in DB and sets pendingCelebration.
  Future<bool> triggerMilestone(String key) async {
    if (state.achievedKeys.contains(key)) return false;

    final isNew = await _db.markMilestoneAchieved(key);
    if (!isNew) return false;

    final updatedKeys = [...state.achievedKeys, key];
    final info = kKnownMilestones[key] ??
        MilestoneInfo(
          key: key,
          title: 'Milestone Unlocked!',
          description: 'You unlocked a new financial milestone.',
          iconType: 'trophy',
        );

    state = state.copyWith(
      achievedKeys: updatedKeys,
      pendingCelebration: info,
    );
    return true;
  }

  void dismissCelebration() {
    state = state.copyWith(clearCelebration: true);
  }
}

final milestoneProvider =
    StateNotifierProvider<MilestoneNotifier, MilestoneState>((ref) {
  final db = ref.watch(databaseProvider);
  return MilestoneNotifier(db);
});

