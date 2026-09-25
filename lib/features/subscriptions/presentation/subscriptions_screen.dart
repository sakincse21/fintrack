import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../recurring/providers/recurring_provider.dart';
import '../../settings/providers/settings_provider.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionsProvider);
    final currency = ref.watch(currencyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
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
        title: const Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 22),
            tooltip: 'Add Subscription',
            onPressed: () => _showAddEditSubscriptionDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: subscriptionsAsync.when(
        data: (summary) {
          if (summary.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 54,
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Subscriptions Tracked Yet',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track Netflix, Spotify, gym, cloud services, and fixed recurring bills to see exactly what drains your money each month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditSubscriptionDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add First Subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Total Monthly Cost Header Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MONTHLY RECURRING SPEND',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${summary.activeCount} active',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          CurrencyFormatter.formatCents(summary.totalMonthlyCents, symbol: currency.symbol),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/ month',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All frequencies normalized to 30-day monthly equivalent.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Subscriptions List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ACTIVE SUBSCRIPTIONS',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Highest cost first',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 3. Subscription Cards
              ...summary.items.map((item) {
                final rule = item.details.rule;
                final cat = item.details.category;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: item.isUnused
                          ? AppColors.warning.withValues(alpha: 0.4)
                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: Icon(
                                IconHelper.getIcon(cat?.icon ?? 'repeat'),
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rule.note.isNotEmpty ? rule.note : (cat?.name ?? 'Subscription'),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Next charge: ${DateFormat('MMM d, yyyy').format(rule.nextRunDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${CurrencyFormatter.formatCents(item.monthlyNormalizedCents, symbol: currency.symbol)}/mo',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  rule.frequency.toUpperCase(),
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                _showAddEditSubscriptionDialog(context, ref, existingRule: rule);
                              } else if (val == 'cancel') {
                                await ref.read(databaseProvider).toggleRecurringRuleActive(rule.id, false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Subscription marked inactive.')),
                                  );
                                }
                              } else if (val == 'history') {
                                context.push('/transactions');
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Edit Subscription'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'history',
                                child: Row(
                                  children: [
                                    Icon(Icons.history_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('View History'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(Icons.block_rounded, size: 16, color: AppColors.expense),
                                    SizedBox(width: 8),
                                    Text('Cancel / Deactivate', style: TextStyle(color: AppColors.expense)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // "Unused?" Flagging
                      if (item.isUnused) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                              SizedBox(width: 6),
                              Text(
                                'Haven\'t confirmed this in a while — consider reviewing',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading subscriptions: $err')),
      ),
    );
  }

  void _showAddEditSubscriptionDialog(
    BuildContext context,
    WidgetRef ref, {
    RecurringRule? existingRule,
  }) {
    final isEditing = existingRule != null;
    final db = ref.read(databaseProvider);
    final nameController = TextEditingController(text: existingRule?.note ?? '');
    final amountController = TextEditingController(
      text: existingRule != null ? (existingRule.amountCents / 100.0).toStringAsFixed(2) : '',
    );
    String frequency = existingRule?.frequency ?? 'monthly';
    int? selectedCategory = existingRule?.categoryId;
    int? selectedAccount = existingRule?.accountId;
    DateTime nextRunDate = existingRule?.nextRunDate ?? DateTime.now().add(const Duration(days: 30));

    final accountsAsync = ref.read(accountsListProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'Edit Subscription' : 'Add Subscription',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Subscription Name',
                        hintText: 'e.g. Netflix, Spotify, Gym',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Price per cycle',
                        hintText: '0.00',
                        prefixIcon: Icon(Icons.paid_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Frequency Selector
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(
                        labelText: 'Billing Frequency',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => frequency = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category Selector
                    FutureBuilder<List<Category>>(
                      future: db.getCategories(type: 'expense'),
                      builder: (context, snapshot) {
                        final cats = snapshot.data ?? [];
                        if (cats.isEmpty) return const SizedBox.shrink();
                        if (selectedCategory == null || !cats.any((c) => c.id == selectedCategory)) {
                          selectedCategory = cats.first.id;
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: cats
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (val) => setState(() => selectedCategory = val),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Account Selector
                    accountsAsync.when(
                      data: (accs) {
                        if (accs.isEmpty) return const SizedBox.shrink();
                        if (selectedAccount == null || !accs.any((a) => a.id == selectedAccount)) {
                          selectedAccount = accs.first.id;
                        }
                        return DropdownButtonFormField<int>(
                          initialValue: selectedAccount,
                          decoration: const InputDecoration(
                            labelText: 'Payment Account',
                            prefixIcon: Icon(Icons.account_balance_outlined),
                          ),
                          items: accs
                              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                              .toList(),
                          onChanged: (val) => setState(() => selectedAccount = val),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 14),

                    // Next Charge Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined, color: AppColors.primary),
                      title: const Text('Next Charge Date', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(DateFormat('MMM d, yyyy').format(nextRunDate)),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nextRunDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setState(() => nextRunDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final amountParsed = CurrencyFormatter.parseAmountToCents(amountController.text) ?? 0;
                          if (name.isEmpty || amountParsed <= 0 || selectedAccount == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide a name, amount, and payment account.')),
                            );
                            return;
                          }

                          final db = ref.read(databaseProvider);
                          if (isEditing) {
                            await (db.update(db.recurringRules)..where((r) => r.id.equals(existingRule.id)))
                                .write(RecurringRulesCompanion(
                              note: drift.Value(name),
                              amountCents: drift.Value(amountParsed),
                              frequency: drift.Value(frequency),
                              categoryId: drift.Value(selectedCategory),
                              accountId: drift.Value(selectedAccount!),
                              nextRunDate: drift.Value(nextRunDate),
                              isSubscription: const drift.Value(true),
                            ));
                          } else {
                            await db.into(db.recurringRules).insert(
                              RecurringRulesCompanion.insert(
                                accountId: selectedAccount!,
                                categoryId: drift.Value(selectedCategory),
                                amountCents: amountParsed,
                                type: 'expense',
                                note: drift.Value(name),
                                frequency: frequency,
                                nextRunDate: nextRunDate,
                                isSubscription: const drift.Value(true),
                              ),
                            );
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isEditing ? 'Subscription updated.' : 'Subscription added!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(isEditing ? 'Save Changes' : 'Add Subscription', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
