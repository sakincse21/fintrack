import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/default_categories.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../quick_add/presentation/quick_add_sheet.dart';
import '../../../settings/providers/settings_provider.dart';

class TransactionDetailDialog extends ConsumerWidget {
  final TransactionWithDetails item;

  const TransactionDetailDialog({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final db = ref.watch(databaseProvider);

    final tx = item.transaction;
    final cat = item.category;
    final acc = item.account;
    final toAcc = item.toAccount;

    final isIncome = tx.type == 'income';
    final isExpense = tx.type == 'expense';
    final isTransfer = tx.type == 'transfer';

    final amountColor = isIncome
        ? AppColors.income
        : isExpense
            ? AppColors.expense
            : AppColors.transfer;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (cat != null ? Color(cat.colorValue) : AppColors.primary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconHelper.getIcon(cat?.icon ?? 'receipt_long'),
                  color: cat != null ? Color(cat.colorValue) : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isTransfer ? 'Transfer Details' : (cat?.name ?? 'Transaction'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Big Amount
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  CurrencyFormatter.formatCents(
                    tx.amountCents,
                    symbol: currency.symbol,
                    showSign: isIncome,
                  ),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Note
            if (tx.note.isNotEmpty) ...[
              _buildDetailRow('Note / Merchant', tx.note, Icons.edit_note),
              const SizedBox(height: 8),
            ],

            // Type
            _buildDetailRow('Type', tx.type.toUpperCase(), Icons.swap_horiz, valueColor: amountColor),
            const SizedBox(height: 8),

            // Account
            _buildDetailRow('Account', acc.name, IconHelper.getIcon(acc.icon)),
            const SizedBox(height: 8),

            // Destination Account if transfer
            if (isTransfer && toAcc != null) ...[
              _buildDetailRow('To Account', toAcc.name, IconHelper.getIcon(toAcc.icon)),
              const SizedBox(height: 8),
            ],

            // Date & Time
            _buildDetailRow(
              'Date & Time',
              '${AppDateUtils.formatFullDate(tx.date)} at ${AppDateUtils.formatTime(tx.date)}',
              Icons.access_time,
            ),
            const SizedBox(height: 8),

            // Tags
            if (tx.tagIds.isNotEmpty) ...[
              _buildDetailRow('Tags', tx.tagIds, Icons.tag),
              const SizedBox(height: 8),
            ],

            // Recurring indicator
            if (tx.isRecurring) ...[
              _buildDetailRow('Recurring Bill', 'Yes (Auto-generated)', Icons.repeat),
              const SizedBox(height: 8),
            ],

            // Receipt Photo Preview
            if (tx.receiptPath != null && tx.receiptPath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Attached Receipt:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(tx.receiptPath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Text('Receipt image not found on device', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Delete button
        TextButton.icon(
          onPressed: () async {
            await db.softDeleteTransaction(tx.id);
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Transaction deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    textColor: AppColors.primaryLight,
                    onPressed: () => db.restoreTransaction(tx.id),
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.expense, size: 18),
          label: const Text('Delete', style: TextStyle(color: AppColors.expense)),
        ),
        // Edit button
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            QuickAddSheet.show(context, editTransaction: tx);
          },
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text('$label:', style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
