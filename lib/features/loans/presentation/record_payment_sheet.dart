import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/loans_provider.dart';

class RecordPaymentSheet extends ConsumerStatefulWidget {
  final LoanWithDetails loanDetails;

  const RecordPaymentSheet({super.key, required this.loanDetails});

  static Future<void> show(BuildContext context, LoanWithDetails loanDetails) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(loanDetails: loanDetails),
    );
  }

  @override
  ConsumerState<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<RecordPaymentSheet> {
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();
  int? _selectedAccountId;
  final DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with remaining amount
    final remaining = widget.loanDetails.remainingCents;
    _amountController = TextEditingController(
      text: (remaining / 100.0).toStringAsFixed(2),
    );
    // Default to the loan's original account
    _selectedAccountId = widget.loanDetails.loan.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final amountCents = CurrencyFormatter.parseAmountToCents(_amountController.text);
    if (amountCents == null || amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      await db.insertLoanPayment(
        LoanPaymentsCompanion.insert(
          loanId: widget.loanDetails.loan.id,
          amountCents: amountCents,
          accountId: _selectedAccountId!,
          paidAt: _paymentDate,
          note: drift.Value(_noteController.text.isEmpty ? null : _noteController.text),
        ),
      );

      if (mounted) {
        // Invalidate the loan detail provider to refresh the parent screen
        ref.invalidate(loanDetailProvider(widget.loanDetails.loan.id));
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ${CurrencyFormatter.formatCompact(amountCents)} recorded',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsListProvider);
    final loan = widget.loanDetails;
    final isLent = loan.loan.type == 'lent';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isLent ? 'Money Returned' : 'Repay Debt',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isLent
                  ? '${loan.person.name} is returning money'
                  : 'Paying back to ${loan.person.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            Text(
              'Remaining: ${CurrencyFormatter.formatCents(loan.remainingCents, symbol: currency.symbol)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '${currency.symbol} ',
                prefixStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Account selector
            accountsAsync.when(
              data: (accounts) {
                final selectedAcc = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
                return InkWell(
                  onTap: () => _showAccountPicker(context, accounts, isDark),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedAcc?.name ?? 'Select account',
                            style: TextStyle(
                              fontWeight: selectedAcc != null ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 15,
                              color: selectedAcc != null ? null : Colors.grey[500],
                            ),
                          ),
                        ),
                        Text(
                          isLent ? 'To' : 'From',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Record Payment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context, List<Account> accounts, bool isDark) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Divider(),
            ...accounts.map((acc) {
              final isSelected = acc.id == _selectedAccountId;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 20,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                title: Text(
                  acc.name,
                  style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                    : null,
                onTap: () {
                  setState(() => _selectedAccountId = acc.id);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

