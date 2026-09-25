import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../milestones/presentation/widgets/milestone_celebration_dialog.dart';
import '../../milestones/providers/milestones_provider.dart';
import '../../quick_add/presentation/quick_add_sheet.dart';
import '../../streaks/presentation/widgets/streak_detail_sheet.dart';
import '../../streaks/providers/streak_provider.dart';
import '../providers/dashboard_provider.dart';
import 'widgets/balance_card.dart';
import 'widgets/budget_glance_card.dart';
import 'widgets/category_donut_card.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/subscriptions_glance_card.dart';
import 'widgets/upcoming_bills_card.dart';
import '../../loans/presentation/widgets/loan_summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning ☀️';
    } else if (hour < 17) {
      return 'Good afternoon 🌤️';
    } else {
      return 'Good evening 🌙';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final streakState = ref.watch(streakProvider).valueOrNull;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen for milestone achievements and show celebration dialog
    ref.listen<MilestoneState>(milestoneProvider, (previous, next) {
      final celebration = next.pendingCelebration;
      if (celebration != null &&
          (previous == null || previous.pendingCelebration?.key != celebration.key)) {
        MilestoneCelebrationDialog.show(context, celebration, () {
          ref.read(milestoneProvider.notifier).dismissCelebration();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        title: Row(
          children: [
            Icon(
              Icons.account_circle_outlined,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'My Finances',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    letterSpacing: -0.4,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Daily Logging Streak
          if (streakState != null)
            IconButton(
              tooltip: 'Daily Streak',
              onPressed: () => StreakDetailSheet.show(context, streakState),
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    streakState.currentStreak > 0 ? '🔥' : '❄️',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${streakState.currentStreak}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: streakState.currentStreak > 0
                          ? AppColors.primary
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardSummaryProvider);
        },
        child: summaryAsync.when(
          data: (summary) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. VittaFinance Hero Total Balance Card (with embedded Income & Expenses pills)
                BalanceCard(
                   totalBalanceCents: summary.totalBalanceCents,
                   incomeCents: summary.thisMonthIncomeCents,
                   expenseCents: summary.thisMonthExpenseCents,
                 ),
                 const SizedBox(height: 18),

                 // 3. VittaFinance 4-Column Quick Action Strip
                 _buildQuickActionGrid(context, isDark),
                 const SizedBox(height: 20),

                 // 4. VittaFinance Spending Category Donut & Breakdown
                 CategoryDonutCard(
                   categories: summary.topCategories,
                   totalExpenseCents: summary.thisMonthExpenseCents,
                 ),
                 const SizedBox(height: 16),

                 // 5. Upcoming Bills
                 const UpcomingBillsCard(),
                 const SizedBox(height: 16),

                 // 6. Subscriptions Glance Card
                 const SubscriptionsGlanceCard(),
                 const SizedBox(height: 16),

                 // 7. Active Budgets Glance
                 const BudgetGlanceCard(),
                 const SizedBox(height: 16),

                 // 8. Dues & Debts Glance
                 const LoanSummaryCard(),

                 // 9. Recent Transactions List
                 const RecentTransactionsCard(),
                 const SizedBox(height: 36),
               ],
             );
           },
           loading: () => const Center(child: CircularProgressIndicator()),
           error: (err, stack) => Center(
             child: Padding(
               padding: const EdgeInsets.all(20),
               child: Text('Error loading dashboard: $err'),
             ),
           ),
         ),
       ),
     );
   }

   Widget _buildQuickActionGrid(BuildContext context, bool isDark) {
     return Row(
       children: [
         Expanded(
           child: _buildActionItem(
             context: context,
             icon: Icons.account_balance_wallet_outlined,
             label: 'Add Expense',
             onTap: () => QuickAddSheet.show(context, initialType: 'expense'),
             isDark: isDark,
           ),
         ),
         const SizedBox(width: 8),
         Expanded(
           child: _buildActionItem(
             context: context,
             icon: Icons.savings_outlined,
             label: 'Add Income',
             onTap: () => QuickAddSheet.show(context, initialType: 'income'),
             isDark: isDark,
           ),
         ),
         const SizedBox(width: 8),
         Expanded(
           child: _buildActionItem(
             context: context,
             icon: Icons.swap_horiz_rounded,
             label: 'Transfer',
             onTap: () => QuickAddSheet.show(context, initialType: 'transfer'),
             isDark: isDark,
           ),
         ),
         const SizedBox(width: 8),
         Expanded(
           child: _buildActionItem(
             context: context,
             icon: Icons.pie_chart_outline_rounded,
             label: 'Analytics',
             onTap: () => context.go('/reports'),
             isDark: isDark,
           ),
         ),
       ],
     );
   }

   Widget _buildActionItem({
     required BuildContext context,
     required IconData icon,
     required String label,
     required VoidCallback onTap,
     required bool isDark,
   }) {
     return InkWell(
       onTap: onTap,
       borderRadius: BorderRadius.circular(20),
       child: Container(
         padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
         decoration: BoxDecoration(
           color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
           borderRadius: BorderRadius.circular(20),
           border: Border.all(
             color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
             width: 1.0,
           ),
           boxShadow: [
             BoxShadow(
               color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
               blurRadius: 10,
               offset: const Offset(0, 3),
             ),
           ],
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Padding(
               padding: const EdgeInsets.all(4),
               child: Icon(
                 icon,
                 color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                 size: 22,
               ),
             ),
             const SizedBox(height: 8),
             Text(
               label,
               style: TextStyle(
                 fontSize: 12,
                 fontWeight: FontWeight.w700,
                 color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
               ),
               textAlign: TextAlign.center,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
           ],
         ),
       ),
     );
   }
}
