import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/accounts_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _showAddEditAccountDialog(BuildContext context, WidgetRef ref, {Account? existing}) {
    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);

    final nameController = TextEditingController(text: existing?.name ?? '');
    final balanceController = TextEditingController(
      text: existing != null ? (existing.initialBalanceCents / 100.0).toStringAsFixed(2) : '0.00',
    );
    String selectedType = existing?.type ?? 'bank';
    String selectedIcon = existing?.icon ?? 'account_balance';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Account' : 'Add New Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Account Name', hintText: 'e.g. Chase Checking, Cash'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Account Type'),
                    items: const [
                      DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                      DropdownMenuItem(value: 'cash', child: Text('Cash Wallet')),
                      DropdownMenuItem(value: 'mobile_banking', child: Text('Mobile Wallet / bKash / Venmo')),
                      DropdownMenuItem(value: 'card', child: Text('Credit Card (Liability)')),
                      DropdownMenuItem(value: 'investment', child: Text('Investment')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedType = val;
                          if (val == 'cash') {
                            selectedIcon = 'payments';
                          } else if (val == 'card') {
                            selectedIcon = 'credit_card';
                          } else if (val == 'mobile_banking') {
                            selectedIcon = 'phone_android';
                          } else {
                            selectedIcon = 'account_balance';
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balanceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Initial Balance (${currency.symbol})',
                      prefixText: '${currency.symbol} ',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    // Archive account
                    await (db.update(db.accounts)..where((a) => a.id.equals(existing.id))).write(
                      const AccountsCompanion(isArchived: drift.Value(true)),
                    );
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Archive', style: TextStyle(color: AppColors.expense)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final balCents = CurrencyFormatter.parseAmountToCents(balanceController.text) ?? 0;

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an account name')),
                    );
                    return;
                  }

                  if (existing != null) {
                    await (db.update(db.accounts)..where((a) => a.id.equals(existing.id))).write(
                      AccountsCompanion(
                        name: drift.Value(name),
                        type: drift.Value(selectedType),
                        initialBalanceCents: drift.Value(balCents),
                        icon: drift.Value(selectedIcon),
                      ),
                    );
                  } else {
                    await db.into(db.accounts).insert(
                      AccountsCompanion.insert(
                        name: name,
                        type: selectedType,
                        initialBalanceCents: drift.Value(balCents),
                        currency: drift.Value(currency.code),
                        icon: drift.Value(selectedIcon),
                      ),
                    );
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: Text(existing != null ? 'Save Changes' : 'Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, List<AccountWithBalance> accounts) {
    final seenIds = <int>{};
    final uniqueAccounts = accounts.where((a) => seenIds.add(a.account.id)).toList();
    if (uniqueAccounts.length < 2) return;

    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);

    int fromAccountId = uniqueAccounts.first.account.id;
    int toAccountId = uniqueAccounts[1].account.id;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final toAccounts = uniqueAccounts.where((a) => a.account.id != fromAccountId).toList();
          if (!toAccounts.any((a) => a.account.id == toAccountId)) {
            toAccountId = toAccounts.isNotEmpty ? toAccounts.first.account.id : 0;
          }

          return AlertDialog(
            title: const Text('Account Transfer'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    key: ValueKey('dialog_from_acc_$fromAccountId'),
                    initialValue: fromAccountId,
                    decoration: const InputDecoration(labelText: 'From Account'),
                    items: uniqueAccounts.map((a) => DropdownMenuItem(value: a.account.id, child: Text(a.account.name))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          fromAccountId = val;
                          final newTo = uniqueAccounts.where((a) => a.account.id != val).toList();
                          if (!newTo.any((a) => a.account.id == toAccountId)) {
                            toAccountId = newTo.isNotEmpty ? newTo.first.account.id : 0;
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (toAccounts.isNotEmpty)
                    DropdownButtonFormField<int>(
                      key: ValueKey('dialog_to_acc_${toAccountId}_from_$fromAccountId'),
                      initialValue: toAccountId,
                      decoration: const InputDecoration(labelText: 'To Account'),
                      items: toAccounts
                          .map((a) => DropdownMenuItem(value: a.account.id, child: Text(a.account.name)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => toAccountId = val);
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Transfer Amount (${currency.symbol})',
                      prefixText: '${currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Note (Optional)', hintText: 'e.g. ATM withdrawal'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final cents = CurrencyFormatter.parseAmountToCents(amountController.text);
                  if (cents == null || cents <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                    return;
                  }

                  await db.into(db.transactions).insert(
                    TransactionsCompanion.insert(
                      accountId: fromAccountId,
                      toAccountId: drift.Value(toAccountId),
                      amountCents: cents,
                      type: 'transfer',
                      note: drift.Value(noteController.text.trim()),
                      date: DateTime.now(),
                    ),
                  );
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text('Execute Transfer'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final currency = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 20),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Accounts & Net Worth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
            tooltip: 'Transfer',
            onPressed: () {
              final accounts = netWorthAsync.valueOrNull?.accountsWithBalance ?? [];
              if (accounts.length >= 2) {
                _showTransferDialog(context, ref, accounts);
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            tooltip: 'Add Account',
            onPressed: () => _showAddEditAccountDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: netWorthAsync.when(
        data: (summary) {
          final assetAccounts = summary.accountsWithBalance.where((a) => !a.isLiability).toList();
          final liabilityAccounts = summary.accountsWithBalance.where((a) => a.isLiability).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Net Worth Gradient Header Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF312E81), Color(0xFF4338CA), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Net Worth', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatCents(summary.netWorthCents, symbol: currency.symbol),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assets', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                CurrencyFormatter.formatCents(summary.totalAssetsCents, symbol: currency.symbol),
                                style: const TextStyle(color: AppColors.primaryLight, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Liabilities', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                CurrencyFormatter.formatCents(summary.totalLiabilitiesCents, symbol: currency.symbol),
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Transfer Button
              OutlinedButton.icon(
                onPressed: () => _showTransferDialog(context, ref, summary.accountsWithBalance),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Transfer Between Accounts'),
              ),
              const SizedBox(height: 20),

              // Asset Accounts Section
              const Text('Asset Accounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (assetAccounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No asset accounts yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ...assetAccounts.map((item) => _buildAccountItemCard(context, ref, item, currency.symbol)),
              const SizedBox(height: 20),

              // Liability Accounts Section
              if (liabilityAccounts.isNotEmpty) ...[
                const Text('Liabilities & Credit Cards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...liabilityAccounts.map((item) => _buildAccountItemCard(context, ref, item, currency.symbol)),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading accounts: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditAccountDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAccountItemCard(BuildContext context, WidgetRef ref, AccountWithBalance item, String symbol) {
    final acc = item.account;
    final balCents = item.balanceCents;
    final isNegative = balCents < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showAddEditAccountDialog(context, ref, existing: acc),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(IconHelper.getIcon(acc.icon), color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      acc.type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatCents(balCents, symbol: symbol),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isNegative ? AppColors.expense : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
