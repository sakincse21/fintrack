import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../milestones/providers/milestones_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/goals_provider.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  void _showAddEditGoalDialog(BuildContext context, WidgetRef ref, {Goal? existing}) {
    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);
    final accountsAsync = ref.read(accountsListProvider);

    final nameController = TextEditingController(text: existing?.name ?? '');
    final targetController = TextEditingController(
      text: existing != null ? (existing.targetAmountCents / 100.0).toStringAsFixed(2) : '',
    );
    final currentController = TextEditingController(
      text: existing != null ? (existing.currentAmountCents / 100.0).toStringAsFixed(2) : '0.00',
    );
    DateTime selectedDate = existing?.targetDate ?? DateTime.now().add(const Duration(days: 180));
    int? linkedAccountId = existing?.linkedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Savings Goal' : 'Create Savings Goal', style: const TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      hintText: 'e.g. Emergency Fund, New Laptop',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Target Amount (${currency.symbol})',
                      prefixText: '${currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currentController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Current Saved Amount (${currency.symbol})',
                      prefixText: '${currency.symbol} ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Target Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Target Date',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.calendar, size: 16),
                          const SizedBox(width: 8),
                          Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Linked Account (Optional)
                  accountsAsync.when(
                    data: (rawAccounts) {
                      final seenIds = <int>{};
                      final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                      final selectedVal = (linkedAccountId != null && accounts.any((a) => a.id == linkedAccountId))
                          ? linkedAccountId
                          : null;

                      return DropdownButtonFormField<int?>(
                        key: ValueKey('goal_linked_acc_$selectedVal'),
                        initialValue: selectedVal,
                        decoration: const InputDecoration(
                          labelText: 'Linked Account (Optional)',
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None (Standalone)')),
                          ...accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
                        ],
                        onChanged: (val) => setState(() => linkedAccountId = val),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDeleteGoal(context, ref, existing);
                  },
                  child: const Text('Delete Goal', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.w700)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final targetCents = CurrencyFormatter.parseAmountToCents(targetController.text);
                  final currentCents = CurrencyFormatter.parseAmountToCents(currentController.text) ?? 0;

                  if (name.isEmpty || targetCents == null || targetCents <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid goal name and target amount')),
                    );
                    return;
                  }

                  if (existing != null) {
                    await (db.update(db.goals)..where((g) => g.id.equals(existing.id))).write(
                      GoalsCompanion(
                        name: drift.Value(name),
                        targetAmountCents: drift.Value(targetCents),
                        currentAmountCents: drift.Value(currentCents),
                        targetDate: drift.Value(selectedDate),
                        linkedAccountId: drift.Value(linkedAccountId),
                      ),
                    );
                  } else {
                    await db.into(db.goals).insert(
                      GoalsCompanion.insert(
                        name: name,
                        targetAmountCents: targetCents,
                        currentAmountCents: drift.Value(currentCents),
                        targetDate: selectedDate,
                        linkedAccountId: drift.Value(linkedAccountId),
                      ),
                    );
                  }
                  if (currentCents >= targetCents) {
                    ref.read(milestoneProvider.notifier).triggerMilestone('first_goal');
                  }
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: Text(existing != null ? 'Save Changes' : 'Create Goal'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteGoal(BuildContext context, WidgetRef ref, Goal goal) {
    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);
    final accountsAsync = ref.read(accountsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasFunds = goal.currentAmountCents > 0;
    final fundsStr = CurrencyFormatter.formatCents(goal.currentAmountCents, symbol: currency.symbol);

    if (!hasFunds) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Goal?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Are you sure you want to delete "${goal.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await (db.delete(db.goals)..where((g) => g.id.equals(goal.id))).go();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Goal "${goal.name}" deleted')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      return;
    }

    int? targetAccountId = goal.linkedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.triangleAlert, color: AppColors.warning, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Delete Goal with Saved Funds', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        Text(
                          fundsStr,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.income, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'This goal currently holds accumulated savings. What would you like to do with these funds?',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),

                  accountsAsync.when(
                    data: (rawAccounts) {
                      final seenIds = <int>{};
                      final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                      if (accounts.isEmpty) return const SizedBox.shrink();

                      if (targetAccountId == null || !accounts.any((a) => a.id == targetAccountId)) {
                        targetAccountId = accounts.first.id;
                      }

                      return DropdownButtonFormField<int>(
                        key: ValueKey('goal_del_target_acc_$targetAccountId'),
                        initialValue: targetAccountId,
                        decoration: const InputDecoration(
                          labelText: 'Transfer Funds To Account',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: accounts.map((a) {
                          return DropdownMenuItem<int>(
                            value: a.id,
                            child: Text(a.name, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => targetAccountId = val),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await (db.delete(db.goals)..where((g) => g.id.equals(goal.id))).go();
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Goal "${goal.name}" deleted. Funds discarded without transaction.')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: const BorderSide(color: AppColors.expense),
                ),
                child: const Text('Discard & Delete'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (targetAccountId != null) {
                    await db.into(db.transactions).insert(
                      TransactionsCompanion.insert(
                        accountId: targetAccountId!,
                        amountCents: goal.currentAmountCents,
                        type: 'income',
                        note: drift.Value('Transferred from deleted goal: ${goal.name}'),
                        date: DateTime.now(),
                      ),
                    );
                  }

                  await (db.delete(db.goals)..where((g) => g.id.equals(goal.id))).go();

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Goal "${goal.name}" deleted. $fundsStr transferred to account.')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.income),
                child: const Text('Transfer & Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDepositWithdrawDialog(BuildContext context, WidgetRef ref, Goal goal, {bool isDeposit = true}) {
    final db = ref.read(databaseProvider);
    final currency = ref.read(currencyProvider);
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Add Funds to Goal' : 'Withdraw Funds from Goal', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Goal: ${goal.name}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount (${currency.symbol})',
                prefixText: '${currency.symbol} ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final cents = CurrencyFormatter.parseAmountToCents(amountController.text);
              if (cents == null || cents <= 0) return;

              int newAmount;
              if (isDeposit) {
                newAmount = goal.currentAmountCents + cents;
              } else {
                newAmount = (goal.currentAmountCents - cents).clamp(0, goal.targetAmountCents * 2);
              }

              await (db.update(db.goals)..where((g) => g.id.equals(goal.id))).write(
                GoalsCompanion(currentAmountCents: drift.Value(newAmount)),
              );

              if (isDeposit && newAmount >= goal.targetAmountCents) {
                ref.read(milestoneProvider.notifier).triggerMilestone('first_goal');
              }

              if (context.mounted) Navigator.pop(ctx);
            },
            child: Text(isDeposit ? 'Deposit' : 'Withdraw'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsListProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
        title: const Text('Savings Goals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 20),
            tooltip: 'Create Goal',
            onPressed: () => _showAddEditGoalDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.target, size: 54, color: Colors.grey.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text(
                    'No savings goals yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set a goal to track your savings targets & progress',
                    style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _showAddEditGoalDialog(context, ref),
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Create Savings Goal'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final item = goals[index];
              final goal = item.goal;
              final progressPct = (item.progress * 100).toInt();

              final currentStr = CurrencyFormatter.formatCents(goal.currentAmountCents, symbol: currency.symbol);
              final targetStr = CurrencyFormatter.formatCents(goal.targetAmountCents, symbol: currency.symbol);
              final monthlyStr = CurrencyFormatter.formatCents(item.suggestedMonthlyContributionCents, symbol: currency.symbol);

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Circular Progress Ring
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: item.progress,
                                strokeWidth: 5,
                                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.isCompleted ? AppColors.income : AppColors.primary,
                                ),
                              ),
                              Text(
                                '$progressPct%',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                  ),
                                  // Edit & Delete Action Icons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 16),
                                        tooltip: 'Edit Goal',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _showAddEditGoalDialog(context, ref, existing: goal),
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.expense),
                                        tooltip: 'Delete Goal',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _confirmDeleteGoal(context, ref, goal),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                '$currentStr of $targetStr',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Target: ${DateFormat('MMM yyyy').format(goal.targetDate)} (${item.daysRemaining} days left)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 10),

                    // Live Monthly Contribution & Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Suggested Monthly',
                              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                            Text(
                              item.isCompleted ? '🎉 Goal Completed!' : '$monthlyStr / mo',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: item.isCompleted ? AppColors.income : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _showDepositWithdrawDialog(context, ref, goal, isDeposit: false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Withdraw', style: TextStyle(fontSize: 11.5)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _showDepositWithdrawDialog(context, ref, goal, isDeposit: true),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('+ Deposit', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
