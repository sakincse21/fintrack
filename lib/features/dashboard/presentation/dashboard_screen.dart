import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../quick_add/presentation/quick_add_sheet.dart';
import '../providers/dashboard_provider.dart';
import 'widgets/balance_card.dart';
import 'widgets/budget_glance_card.dart';
import 'widgets/category_donut_card.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/upcoming_bills_card.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        title: Row(
          children: [
            // User Avatar Squircle
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.4),
              ),
              child: const Center(
                child: Icon(LucideIcons.user, color: AppColors.primary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
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
              child: const Icon(LucideIcons.slidersHorizontal, size: 18),
            ),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 12),
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

                // 2. VittaFinance 4-Column Quick Action Strip
                _buildQuickActionGrid(context, isDark),
                const SizedBox(height: 20),

                // 3. VittaFinance Spending Category Donut & Breakdown
                CategoryDonutCard(
                  categories: summary.topCategories,
                  totalExpenseCents: summary.thisMonthExpenseCents,
                ),
                const SizedBox(height: 16),

                // 4. Upcoming Bills
                const UpcomingBillsCard(),
                const SizedBox(height: 16),

                // 5. Active Budgets Glance
                const BudgetGlanceCard(),
                const SizedBox(height: 16),

                // 6. Recent Transactions List
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
            icon: LucideIcons.wallet,
            color: AppColors.expense,
            label: 'Add Expense',
            onTap: () => QuickAddSheet.show(context, initialType: 'expense'),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionItem(
            context: context,
            icon: LucideIcons.handCoins,
            color: AppColors.income,
            label: 'Add Income',
            onTap: () => QuickAddSheet.show(context, initialType: 'income'),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionItem(
            context: context,
            icon: LucideIcons.arrowLeftRight,
            color: AppColors.transfer,
            label: 'Transfer',
            onTap: () => QuickAddSheet.show(context, initialType: 'transfer'),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionItem(
            context: context,
            icon: LucideIcons.chartPie,
            color: AppColors.warning,
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
    required Color color,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
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
