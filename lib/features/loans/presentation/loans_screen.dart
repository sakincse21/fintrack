import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/loans_provider.dart';
import 'add_loan_sheet.dart';
import 'loan_detail_screen.dart';
import 'widgets/loan_card.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          toolbarHeight: 64,
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 22),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
          title: const Text(
            'Dues & Debts',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'Settled'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Summary header
            _buildSummaryHeader(context, ref),
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  _buildActiveTab(context, ref),
                  _buildSettledTab(context, ref),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => AddLoanSheet.show(context),
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(17),
                child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(loanSummaryProvider);
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasActiveLoans) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  context,
                  icon: Icons.arrow_outward_rounded,
                  iconColor: AppColors.expense,
                  label: "You're owed",
                  amount: CurrencyFormatter.formatCents(summary.totalLentCents, symbol: currency.symbol),
                  count: summary.activeLentCount,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  context,
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.income,
                  label: 'You owe',
                  amount: CurrencyFormatter.formatCents(summary.totalBorrowedCents, symbol: currency.symbol),
                  count: summary.activeBorrowedCount,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String amount,
    required int count,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$count active',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTab(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(activeLoansProvider);

    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) {
          return _buildEmptyState(context);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return LoanCard(
              loanWithDetails: loan,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoanDetailScreen(loanId: loan.loan.id),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSettledTab(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(settledLoansProvider);

    return loansAsync.when(
      data: (loans) {
        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No settled loans yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return Opacity(
              opacity: 0.7,
              child: LoanCard(
                loanWithDetails: loan,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoanDetailScreen(loanId: loan.loan.id),
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No active dues or debts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to track money you give or receive',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

