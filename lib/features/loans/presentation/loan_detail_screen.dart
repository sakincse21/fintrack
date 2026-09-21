import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/loans_provider.dart';
import 'record_payment_sheet.dart';

class LoanDetailScreen extends ConsumerWidget {
  final int loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(loanDetailProvider(loanId));
    final paymentsAsync = ref.watch(loanPaymentsProvider(loanId));
    final currency = ref.watch(currencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 22),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Loan Details',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'settle', child: Text('Mark as Settled')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Loan')),
            ],
          ),
        ],
      ),
      body: loanAsync.when(
        data: (loan) {
          if (loan == null) {
            return const Center(child: Text('Loan not found'));
          }
          return _buildBody(context, ref, loan, paymentsAsync, currency, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LoanWithDetails loanDetails,
    AsyncValue<List<LoanPayment>> paymentsAsync,
    CurrencyInfo currency,
    bool isDark,
  ) {
    final loan = loanDetails.loan;
    final person = loanDetails.person;
    final isLent = loan.type == 'lent';
    final typeColor = isLent ? AppColors.expense : AppColors.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Main info card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Person header
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          if (person.phone != null && person.phone!.isNotEmpty)
                            Text(
                              person.phone!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        loanDetails.typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount section
                Text(
                  CurrencyFormatter.formatCents(loan.amountCents, symbol: currency.symbol),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total amount',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: loanDetails.progressPercent,
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),

                // Paid / Remaining
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid: ${CurrencyFormatter.formatCents(loanDetails.paidAmountCents, symbol: currency.symbol)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                    Text(
                      'Remaining: ${CurrencyFormatter.formatCents(loanDetails.remainingCents, symbol: currency.symbol)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                    ),
                  ],
                ),

                // Status badges
                if (loanDetails.isOverdue || loan.isSettled) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loanDetails.isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.alertTriangle, size: 14, color: Colors.red),
                              SizedBox(width: 4),
                              Text('Overdue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)),
                            ],
                          ),
                        ),
                      if (loan.isSettled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.checkCircle, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text('Settled', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Details card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(LucideIcons.wallet, 'Account', loanDetails.account.name),
                if (loan.dueDate != null) ...[
                  const Divider(height: 20),
                  _buildDetailRow(
                    LucideIcons.calendar,
                    'Due Date',
                    DateFormat('MMM d, yyyy').format(loan.dueDate!),
                    valueColor: loanDetails.isOverdue ? Colors.red : null,
                  ),
                ],
                if (loan.reminderOption != 'none') ...[
                  const Divider(height: 20),
                  _buildDetailRow(LucideIcons.bell, 'Reminder', _formatReminder(loan.reminderOption)),
                ],
                const Divider(height: 20),
                _buildDetailRow(
                  LucideIcons.clock,
                  'Created',
                  DateFormat('MMM d, yyyy • h:mm a').format(loan.createdAt),
                ),
                if (loan.note != null && loan.note!.isNotEmpty) ...[
                  const Divider(height: 20),
                  _buildDetailRow(LucideIcons.fileText, 'Note', loan.note!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Payment history
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (!loan.isSettled)
              TextButton.icon(
                onPressed: () => RecordPaymentSheet.show(context, loanDetails),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Record Payment'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        paymentsAsync.when(
          data: (payments) {
            if (payments.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(LucideIcons.receipt, size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No payments recorded yet',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: payments.map((payment) {
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(LucideIcons.arrowDownLeft, size: 18, color: Colors.green),
                    ),
                    title: Text(
                      CurrencyFormatter.formatCents(payment.amountCents, symbol: currency.symbol),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(payment.paidAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    trailing: payment.note != null && payment.note!.isNotEmpty
                        ? Tooltip(
                            message: payment.note!,
                            child: Icon(LucideIcons.fileText, size: 16, color: Colors.grey[400]),
                          )
                        : null,
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _formatReminder(String option) {
    switch (option) {
      case '1_day':
        return '1 day before';
      case '3_days':
        return '3 days before';
      case '1_week':
        return '1 week before';
      case '2_weeks':
        return '2 weeks before';
      case '1_month':
        return '1 month before';
      default:
        return 'None';
    }
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final db = ref.read(databaseProvider);

    switch (action) {
      case 'settle':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mark as Settled?'),
            content: const Text('This will mark the loan as settled, even if not fully paid. This is useful for loan forgiveness or adjustments.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Settle', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await db.settleLoan(loanId);
          if (context.mounted) {
            ref.invalidate(loanDetailProvider(loanId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Loan marked as settled')),
            );
          }
        }
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Loan?'),
            content: const Text('This will permanently delete this loan and all its payment records. This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await db.deleteLoan(loanId);
          if (context.mounted) Navigator.of(context).maybePop();
        }
        break;
    }
  }
}

