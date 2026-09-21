import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../milestones/providers/milestones_provider.dart';
import '../../settings/presentation/category_manager_screen.dart';
import '../../settings/providers/settings_provider.dart';
import '../../streaks/providers/streak_provider.dart';
import '../../loans/presentation/widgets/person_picker.dart';
import '../../loans/providers/loans_provider.dart';
import 'widgets/natural_voice_input_dialog.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  final TransactionItem? editTransaction;
  final String? initialType;

  const QuickAddSheet({super.key, this.editTransaction, this.initialType});

  static Future<void> show(BuildContext context, {TransactionItem? editTransaction, String? initialType}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(
        editTransaction: editTransaction,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  String _amountInput = '';
  String _selectedType = 'expense'; // 'expense', 'income', 'transfer', 'dues'
  int? _selectedCategoryId;
  int? _selectedAccountId;
  int? _selectedToAccountId; // for transfer
  DateTime _selectedDate = DateTime.now();
  bool _saveAndAddAnother = false;
  bool _isAutoMatched = false;
  bool _showMoreOptions = false;

  // Dues & Debts specific state
  String _duesSubType = 'lent'; // 'lent' (Money Given) or 'borrowed' (Money Received)
  Person? _selectedPerson;
  DateTime? _returnDate;
  String _duesReminderOption = 'none'; // 'none', '1_day', '3_days', '1_week', '2_weeks', '1_month'
  LoanWithDetails? _selectedDuesLoan; // For paying an expense through a friend's debt to me (friend owes me)
  LoanWithDetails? _selectedRepayDebtLoan; // For paying a friend's bill to reduce my debt to them (I owe friend)

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _selectedType = tx.type;
      final amt = (tx.amountCents / 100.0);
      _amountInput = amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
      _amountController.text = _amountInput;
      _noteController.text = tx.note;
      _selectedCategoryId = tx.categoryId;
      _selectedAccountId = tx.accountId;
      _selectedToAccountId = tx.toAccountId;
      _selectedDate = tx.date;
      _tagController.text = tx.tagIds;
      _showMoreOptions = tx.tagIds.isNotEmpty;
    }

    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _amountController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _onNoteChanged() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _selectedType == 'transfer' || _selectedType == 'dues') return;

    final db = ref.read(databaseProvider);
    final matchedCat = await db.findCategoryByMerchant(text);

    if (matchedCat != null && mounted) {
      setState(() {
        _selectedCategoryId = matchedCat.id;
        _isAutoMatched = true;
      });
    }
  }

  void _onKeypadTap(String value) {
    setState(() {
      if (value == '.') {
        if (_amountInput.contains('.')) return;
        if (_amountInput.isEmpty) {
          _amountInput = '0.';
        } else {
          _amountInput += '.';
        }
      } else {
        // Digits 0-9
        if (_amountInput == '0') {
          _amountInput = value;
        } else if (_amountInput.contains('.')) {
          final parts = _amountInput.split('.');
          if (parts.length > 1 && parts[1].length >= 2) {
            return; // cap cents at 2 decimal places
          }
          _amountInput += value;
        } else {
          if (_amountInput.length >= 8) return;
          _amountInput += value;
        }
      }
      _amountController.text = _amountInput;
    });
  }

  void _onKeypadBackspace() {
    setState(() {
      if (_amountInput.isNotEmpty) {
        _amountInput = _amountInput.substring(0, _amountInput.length - 1);
        _amountController.text = _amountInput;
      }
    });
  }

  void _onKeypadClear() {
    setState(() {
      _amountInput = '';
      _amountController.text = '';
    });
  }

  String _formatDisplayDateTime(DateTime date) {
    final timeStr = DateFormat('h:mm a').format(date);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) {
      return 'Today · $timeStr';
    } else if (diff == -1) {
      return 'Yesterday · $timeStr';
    } else {
      return '${DateFormat('d MMM, yyyy').format(date)} · $timeStr';
    }
  }

  void _showAccountPicker(
    BuildContext context,
    List<Account> accounts, {
    required bool isToAccount,
    List<LoanWithDetails> activeLoans = const [],
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currency = ref.read(currencyProvider);
    final currentId = isToAccount ? _selectedToAccountId : _selectedAccountId;

    final eligibleLoans = (!isToAccount && _selectedType == 'expense' && widget.editTransaction == null)
        ? activeLoans.where((l) => l.loan.type == 'lent' && !l.loan.isSettled && l.remainingCents > 0).toList()
        : <LoanWithDetails>[];

    final borrowedLoans = (!isToAccount && _selectedType == 'expense' && widget.editTransaction == null)
        ? activeLoans.where((l) => l.loan.type == 'borrowed' && !l.loan.isSettled && l.remainingCents > 0).toList()
        : <LoanWithDetails>[];

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      isToAccount ? 'Select Destination Account' : 'Select Account / Payment Method',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 4),
                    child: Text(
                      'YOUR ACCOUNTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  ...accounts.map((acc) {
                    final isSelected = _selectedDuesLoan == null && _selectedRepayDebtLoan == null && acc.id == currentId;
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(IconHelper.getIcon(acc.icon), size: 18),
                      ),
                      title: Text(acc.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedDuesLoan = null;
                          _selectedRepayDebtLoan = null;
                          if (isToAccount) {
                            _selectedToAccountId = acc.id;
                          } else {
                            _selectedAccountId = acc.id;
                            if (_selectedToAccountId == acc.id) {
                              final others = accounts.where((a) => a.id != acc.id).toList();
                              _selectedToAccountId = others.isNotEmpty ? others.first.id : null;
                            }
                          }
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  }),
                  if (eligibleLoans.isNotEmpty) ...[
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.handCoins, size: 14, color: AppColors.income),
                              const SizedBox(width: 6),
                              Text(
                                "FRIEND PAYS (DEDUCT FROM DUE)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Friend pays this bill; deducted from what they owe you',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...eligibleLoans.map((l) {
                      final isSelected = _selectedDuesLoan?.loan.id == l.loan.id;
                      final remainingStr = CurrencyFormatter.formatCents(l.remainingCents, symbol: currency.symbol);
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.income.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l.person.name.isNotEmpty ? l.person.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.income,
                            ),
                          ),
                        ),
                        title: Text(
                          l.person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Owes $remainingStr${l.loan.note != null && l.loan.note!.isNotEmpty ? ' · ${l.loan.note}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.income,
                                  ),
                                ),
                              ),
                        onTap: () {
                          setState(() {
                            _selectedDuesLoan = l;
                            _selectedRepayDebtLoan = null;
                            _selectedAccountId = l.loan.accountId;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }),
                  ],
                  if (borrowedLoans.isNotEmpty) ...[
                    const Divider(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.arrowUpRight, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                "I PAY FOR FRIEND (REPAY DEBT)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You pay friend\'s bill from your account; reduces what you owe them',
                            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white54 : Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...borrowedLoans.map((l) {
                      final isSelected = _selectedRepayDebtLoan?.loan.id == l.loan.id;
                      final remainingStr = CurrencyFormatter.formatCents(l.remainingCents, symbol: currency.symbol);
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l.person.name.isNotEmpty ? l.person.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          l.person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600),
                        ),
                        subtitle: Text(
                          'You owe $remainingStr${l.loan.note != null && l.loan.note!.isNotEmpty ? ' · ${l.loan.note}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                        onTap: () async {
                          if (accounts.length <= 1) {
                            setState(() {
                              _selectedRepayDebtLoan = l;
                              _selectedDuesLoan = null;
                              _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
                            });
                            Navigator.pop(ctx);
                            return;
                          }

                          final chosenAcc = await showDialog<Account>(
                            context: ctx,
                            builder: (dialogCtx) => AlertDialog(
                              title: Text(
                                'Pay on behalf of ${l.person.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Which account did you pay from?',
                                    style: TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  ...accounts.map((acc) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(IconHelper.getIcon(acc.icon), size: 16),
                                    ),
                                    title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    onTap: () => Navigator.pop(dialogCtx, acc),
                                  )),
                                ],
                              ),
                            ),
                          );

                          if (chosenAcc != null && mounted) {
                            setState(() {
                              _selectedRepayDebtLoan = l;
                              _selectedDuesLoan = null;
                              _selectedAccountId = chosenAcc.id;
                            });
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                          }
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveTransaction() async {
    final rawAmount = _amountInput.isNotEmpty ? _amountInput : _amountController.text;
    final cents = CurrencyFormatter.parseAmountToCents(rawAmount);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final accounts = await ref.read(databaseProvider).getAllAccounts();
    if (accounts.isEmpty) return;

    final accountId = _selectedAccountId ?? accounts.first.id;
    final db = ref.read(databaseProvider);
    final note = _noteController.text.trim();

    // Learn merchant rule automatically
    if (note.isNotEmpty && _selectedCategoryId != null && _selectedType == 'expense') {
      await db.saveMerchantRule(note, _selectedCategoryId!);
    }

    if (_selectedType == 'dues') {
      if (_selectedPerson == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a person for dues/debts'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await db.insertLoan(
        LoansCompanion.insert(
          personId: _selectedPerson!.id,
          type: _duesSubType,
          amountCents: cents,
          accountId: accountId,
          createdAt: _selectedDate,
          dueDate: drift.Value(_returnDate),
          reminderOption: drift.Value(_duesReminderOption),
          note: drift.Value(note.isEmpty ? null : note),
        ),
      );

      // Record streak for logging financial activity
      await ref.read(streakProvider.notifier).recordTransactionForStreak(_selectedDate);

      if (_saveAndAddAnother) {
        if (!mounted) return;
        setState(() {
          _amountInput = '';
          _amountController.clear();
          _noteController.clear();
          _tagController.clear();
          _selectedPerson = null;
          _returnDate = null;
          _duesReminderOption = 'none';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dues recorded! Enter next transaction.'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      } else {
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    // Deduct expense from friend's due/loan
    if (_selectedType == 'expense' && _selectedDuesLoan != null) {
      if (cents > _selectedDuesLoan!.remainingCents) {
        final currency = ref.read(currencyProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Amount (${CurrencyFormatter.formatCents(cents, symbol: currency.symbol)}) exceeds ${_selectedDuesLoan!.person.name}\'s remaining due of ${CurrencyFormatter.formatCents(_selectedDuesLoan!.remainingCents, symbol: currency.symbol)}',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final friendName = _selectedDuesLoan!.person.name;
      final effectiveTxNote = note.isEmpty
          ? 'Paid by $friendName (Due deduction)'
          : '$note (Paid by $friendName)';

      // 1. Insert expense transaction
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: _selectedDuesLoan!.loan.accountId,
          categoryId: drift.Value(_selectedCategoryId),
          amountCents: cents,
          type: 'expense',
          note: drift.Value(effectiveTxNote),
          date: _selectedDate,
          tagIds: drift.Value(_tagController.text.trim()),
        ),
      );

      // 2. Insert loan repayment (which automatically records balancing income transaction on the account and auto-settles if loan is cleared)
      final paymentNote = note.isEmpty
          ? 'Loan repayment from $friendName (Paid expense)'
          : 'Repayment from $friendName: $note';

      await db.insertLoanPayment(
        LoanPaymentsCompanion.insert(
          loanId: _selectedDuesLoan!.loan.id,
          amountCents: cents,
          accountId: _selectedDuesLoan!.loan.accountId,
          paidAt: _selectedDate,
          note: drift.Value(paymentNote),
        ),
        createTransaction: true,
      );

      // Record streak and trigger milestones
      await ref.read(streakProvider.notifier).recordTransactionForStreak(_selectedDate);

      // Budget Alert check
      if (_selectedCategoryId != null) {
        final budgets = await db.watchBudgetsWithProgress(_selectedDate).first;
        final matchedBudget = budgets.where((b) => b.category.id == _selectedCategoryId).firstOrNull;
        if (matchedBudget != null) {
          final threshold = ref.read(budgetAlertThresholdProvider);
          if (matchedBudget.progress >= threshold) {
            final currency = ref.read(currencyProvider);
            ref.read(notificationServiceProvider).showBudgetAlert(
                  id: matchedBudget.budget.id,
                  categoryName: matchedBudget.category.name,
                  percentage: matchedBudget.progress,
                  spentFormatted: CurrencyFormatter.formatCents(matchedBudget.spentCents, symbol: currency.symbol),
                  limitFormatted: CurrencyFormatter.formatCents(matchedBudget.budget.amountCents, symbol: currency.symbol),
                );
          }
        }
      }

      if (_saveAndAddAnother) {
        if (!mounted) return;
        setState(() {
          _amountInput = '';
          _amountController.clear();
          _noteController.clear();
          _tagController.clear();
          _isAutoMatched = false;
          _selectedDuesLoan = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Expense logged & deducted from $friendName\'s loan! Enter next.'),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Expense logged & deducted from $friendName\'s loan!'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
      return;
    }

    // Pay bill on behalf of friend (I pay friend's bill to reduce my debt to them)
    if (_selectedType == 'expense' && _selectedRepayDebtLoan != null) {
      if (cents > _selectedRepayDebtLoan!.remainingCents) {
        final currency = ref.read(currencyProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Amount (${CurrencyFormatter.formatCents(cents, symbol: currency.symbol)}) exceeds what you owe ${_selectedRepayDebtLoan!.person.name} (${CurrencyFormatter.formatCents(_selectedRepayDebtLoan!.remainingCents, symbol: currency.symbol)})',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final friendName = _selectedRepayDebtLoan!.person.name;
      final effectiveTxNote = note.isEmpty
          ? 'Paid for $friendName (Debt repayment)'
          : '$note (Paid for $friendName · Debt repayment)';

      // 1. Insert expense transaction (deducts money from user's accountId)
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: drift.Value(_selectedCategoryId),
          amountCents: cents,
          type: 'expense',
          note: drift.Value(effectiveTxNote),
          date: _selectedDate,
          tagIds: drift.Value(_tagController.text.trim()),
        ),
      );

      // 2. Insert loan payment on the borrowed loan (createTransaction: false because the expense already deducted from account)
      final paymentNote = note.isEmpty
          ? 'Paid bill on behalf of $friendName'
          : 'Paid bill: $note';

      await db.insertLoanPayment(
        LoanPaymentsCompanion.insert(
          loanId: _selectedRepayDebtLoan!.loan.id,
          amountCents: cents,
          accountId: accountId,
          paidAt: _selectedDate,
          note: drift.Value(paymentNote),
        ),
        createTransaction: false,
      );

      // Record streak and trigger milestones
      await ref.read(streakProvider.notifier).recordTransactionForStreak(_selectedDate);

      // Budget Alert check
      if (_selectedCategoryId != null) {
        final budgets = await db.watchBudgetsWithProgress(_selectedDate).first;
        final matchedBudget = budgets.where((b) => b.category.id == _selectedCategoryId).firstOrNull;
        if (matchedBudget != null) {
          final threshold = ref.read(budgetAlertThresholdProvider);
          if (matchedBudget.progress >= threshold) {
            final currency = ref.read(currencyProvider);
            ref.read(notificationServiceProvider).showBudgetAlert(
                  id: matchedBudget.budget.id,
                  categoryName: matchedBudget.category.name,
                  percentage: matchedBudget.progress,
                  spentFormatted: CurrencyFormatter.formatCents(matchedBudget.spentCents, symbol: currency.symbol),
                  limitFormatted: CurrencyFormatter.formatCents(matchedBudget.budget.amountCents, symbol: currency.symbol),
                );
          }
        }
      }

      if (_saveAndAddAnother) {
        if (!mounted) return;
        setState(() {
          _amountInput = '';
          _amountController.clear();
          _noteController.clear();
          _tagController.clear();
          _isAutoMatched = false;
          _selectedRepayDebtLoan = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Expense logged & debt to $friendName reduced! Enter next.'),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Expense logged & debt to $friendName reduced!'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
      return;
    }

    if (widget.editTransaction != null) {
      await (db.update(db.transactions)..where((t) => t.id.equals(widget.editTransaction!.id)))
          .write(
        TransactionsCompanion(
          accountId: drift.Value(accountId),
          categoryId: drift.Value(_selectedType == 'transfer' ? null : _selectedCategoryId),
          amountCents: drift.Value(cents),
          type: drift.Value(_selectedType),
          note: drift.Value(note),
          date: drift.Value(_selectedDate),
          tagIds: drift.Value(_tagController.text.trim()),
          toAccountId: drift.Value(_selectedType == 'transfer' ? _selectedToAccountId : null),
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          accountId: accountId,
          categoryId: drift.Value(_selectedType == 'transfer' ? null : _selectedCategoryId),
          amountCents: cents,
          type: _selectedType,
          note: drift.Value(note),
          date: _selectedDate,
          tagIds: drift.Value(_tagController.text.trim()),
          toAccountId: drift.Value(_selectedType == 'transfer' ? _selectedToAccountId : null),
        ),
      );

      // Record streak and trigger milestones
      await ref.read(streakProvider.notifier).recordTransactionForStreak(_selectedDate);
      final txCount = await (db.select(db.transactions)..limit(2)).get();
      if (txCount.length == 1) {
        ref.read(milestoneProvider.notifier).triggerMilestone('first_transaction');
      }

      // Budget Alert check
      if (_selectedType == 'expense' && _selectedCategoryId != null) {
        final budgets = await db.watchBudgetsWithProgress(_selectedDate).first;
        final matchedBudget = budgets.where((b) => b.category.id == _selectedCategoryId).firstOrNull;
        if (matchedBudget != null) {
          final threshold = ref.read(budgetAlertThresholdProvider);
          if (matchedBudget.progress >= threshold) {
            final currency = ref.read(currencyProvider);
            ref.read(notificationServiceProvider).showBudgetAlert(
                  id: matchedBudget.budget.id,
                  categoryName: matchedBudget.category.name,
                  percentage: matchedBudget.progress,
                  spentFormatted: CurrencyFormatter.formatCents(matchedBudget.spentCents, symbol: currency.symbol),
                  limitFormatted: CurrencyFormatter.formatCents(matchedBudget.budget.amountCents, symbol: currency.symbol),
                );
          }
        }
      }

      if (_saveAndAddAnother) {
        if (!mounted) return;
        setState(() {
          _amountInput = '';
          _amountController.clear();
          _noteController.clear();
          _tagController.clear();
          _isAutoMatched = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved! Enter next transaction.'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      } else {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = ref.watch(currencyProvider);
    final accountsAsync = ref.watch(accountsListProvider);
    final activeLoansAsync = ref.watch(activeLoansProvider);
    final db = ref.watch(databaseProvider);
    final isDark = theme.brightness == Brightness.dark;

    final typeColor = _selectedType == 'income'
        ? AppColors.income
        : _selectedType == 'expense'
            ? AppColors.primary
            : _selectedType == 'transfer'
                ? AppColors.transfer
                : AppColors.warning;

    final sheetBg = isDark ? AppColors.darkBackground : const Color(0xFFF5F3EF);

    // Fixed uniform sheet height for all transaction types
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.90;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle & Top Bar (Fixed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.editTransaction != null ? 'Edit Transaction' : 'New Transaction',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable Content Area (Middle)
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP SEGMENTED TYPE SELECTOR
                  _buildTypeSelector(isDark),
                  const SizedBox(height: 10),

                  // 2. HERO AMOUNT & SMART ENTRY
                  _buildHeroAmount(theme, isDark, currency),
                  const SizedBox(height: 12),

                  // 3. HORIZONTALLY SCROLLABLE CATEGORY ROW (Expense/Income only)
                  if (_selectedType == 'expense' || _selectedType == 'income') ...[
                    _buildCategorySection(theme, isDark, db),
                    const SizedBox(height: 12),
                  ],

                  // 3b. DUES DIRECTION TOGGLE (Money Given vs Money Received)
                  if (_selectedType == 'dues') ...[
                    _buildDuesDirectionToggle(isDark),
                    const SizedBox(height: 12),
                  ],

                  // 4. DETAILS CARD (Account, Date & Time, Note)
                  accountsAsync.when(
                    data: (accounts) => _buildDetailsCard(
                      theme,
                      isDark,
                      accounts,
                      activeLoans: activeLoansAsync.valueOrNull ?? [],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 8),

                  // 5. TAGS & BATCH ENTRY ROW
                  _buildTagsAndBatchRow(isDark),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),

          // Integrated Numeric Keypad & Save Button (Fixed at bottom for all types)
          Container(
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 14,
              top: 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNumericKeypad(theme, isDark),
                const SizedBox(height: 10),
                _buildSaveButton(theme, isDark, typeColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI SUB-COMPONENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTypeSelector(bool isDark) {
    final types = [
      {'key': 'expense', 'label': 'Expense'},
      {'key': 'income', 'label': 'Income'},
      {'key': 'transfer', 'label': 'Transfer'},
      {'key': 'dues', 'label': 'Dues'},
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedType == t['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = t['key'] as String;
                  if (_selectedType != 'expense') {
                    _selectedDuesLoan = null;
                    _selectedRepayDebtLoan = null;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF18181B))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  t['label'] as String,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? const Color(0xFF18181B) : Colors.white)
                        : (isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDuesDirectionToggle(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _duesSubType = 'lent'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _duesSubType == 'lent'
                    ? AppColors.expense.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _duesSubType == 'lent' ? AppColors.expense : Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.arrowUpRight,
                    color: _duesSubType == 'lent' ? AppColors.expense : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Money Given',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _duesSubType == 'lent' ? AppColors.expense : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _duesSubType = 'borrowed'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _duesSubType == 'borrowed'
                    ? AppColors.income.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _duesSubType == 'borrowed' ? AppColors.income : Colors.black.withValues(alpha: 0.05),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.arrowDownLeft,
                    color: _duesSubType == 'borrowed' ? AppColors.income : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Money Received',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _duesSubType == 'borrowed' ? AppColors.income : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAmount(ThemeData theme, bool isDark, CurrencyInfo currency) {
    final displayAmount = _amountInput.isEmpty ? '0' : _amountInput;

    return Column(
      children: [
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${currency.symbol}$displayAmount',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Tap the keypad or dictate note',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 10),
        // Smart Entry Action Button (Voice removed per user preference)
        _buildSmartEntryButton(isDark),
      ],
    );
  }

  Widget _buildSmartEntryButton(bool isDark) {
    return Material(
      color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => NaturalVoiceInputDialog(
              onParsed: (parsed) {
                setState(() {
                  if (parsed.amountCents != null) {
                    final amt = (parsed.amountCents! / 100.0);
                    _amountInput = amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
                    _amountController.text = _amountInput;
                  }
                  _noteController.text = parsed.note;
                  _selectedType = parsed.type;
                  if (_selectedType != 'expense') {
                    _selectedDuesLoan = null;
                    _selectedRepayDebtLoan = null;
                  }
                });
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 40,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.sparkles, size: 16, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 8),
              Text(
                'Smart Quick Entry',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(ThemeData theme, bool isDark, AppDatabase db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'CATEGORY',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                if (_isAutoMatched) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Auto matched ✨',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // "Add New" button instead of "Manage"
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.plus,
                      size: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF18181B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Add New',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF18181B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Category>>(
          stream: db.watchCategories(type: _selectedType),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? [];
            if (categories.isEmpty) return const SizedBox.shrink();

            if (_selectedCategoryId == null || !categories.any((c) => c.id == _selectedCategoryId)) {
              _selectedCategoryId = categories.first.id;
            }

            // Single horizontally scrollable row of categories
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ...categories.map((cat) {
                    final isSelected = _selectedCategoryId == cat.id;
                    final catColor = Color(cat.colorValue);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategoryId = cat.id;
                            _isAutoMatched = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF18181B))
                                : (isDark ? AppColors.darkSurfaceElevated : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.black.withValues(alpha: 0.05),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconHelper.getIcon(cat.icon),
                                size: 15,
                                color: isSelected
                                    ? (isDark ? const Color(0xFF18181B) : Colors.white)
                                    : catColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF18181B) : Colors.white)
                                      : (isDark ? Colors.white : const Color(0xFF374151)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Add New button pill at end of scroll
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add New',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailsCard(
    ThemeData theme,
    bool isDark,
    List<Account> accounts, {
    List<LoanWithDetails> activeLoans = const [],
  }) {
    final currency = ref.read(currencyProvider);
    Account? selectedAcc;
    try {
      selectedAcc = accounts.firstWhere((a) => a.id == _selectedAccountId);
    } catch (_) {
      selectedAcc = accounts.isNotEmpty ? accounts.first : null;
    }

    Account? selectedToAcc;
    if (_selectedType == 'transfer') {
      try {
        selectedToAcc = accounts.firstWhere((a) => a.id == _selectedToAccountId);
      } catch (_) {
        selectedToAcc = accounts.where((a) => a.id != _selectedAccountId).firstOrNull;
      }
    }


    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // If Dues: Person Selector Row
          if (_selectedType == 'dues') ...[
            InkWell(
              onTap: () async {
                final person = await PersonPicker.show(context, ref);
                if (person != null) {
                  setState(() => _selectedPerson = person);
                }
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Person',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_selectedPerson != null) ...[
                            const Icon(LucideIcons.user, size: 15, color: Colors.grey),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _selectedPerson!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                          ] else
                            const Text(
                              'Select person *',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
          ],

          // Row 1: Account (or From Account / Into Account / Paid by Friend / Repaying Debt)
          InkWell(
            onTap: () => _showAccountPicker(
              context,
              accounts,
              isToAccount: false,
              activeLoans: activeLoans,
            ),
            borderRadius: _selectedType == 'dues' ? null : const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    _selectedType == 'transfer'
                        ? 'From Account'
                        : _selectedType == 'dues'
                            ? (_duesSubType == 'lent' ? 'Paid From' : 'Deposited To')
                            : (_selectedDuesLoan != null
                                ? 'Paid by Friend'
                                : (_selectedRepayDebtLoan != null ? 'Repaying Debt' : 'Account')),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_selectedDuesLoan != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.income.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.handCoins, size: 12, color: AppColors.income),
                                SizedBox(width: 4),
                                Text(
                                  'Due Offset',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.income,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _selectedDuesLoan!.person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                        ] else if (_selectedRepayDebtLoan != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.arrowUpRight, size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Repaying',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${selectedAcc?.name ?? ''} • ${_selectedRepayDebtLoan!.person.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                        ] else if (selectedAcc != null) ...[
                          Icon(IconHelper.getIcon(selectedAcc.icon), size: 15, color: Colors.grey),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              selectedAcc.name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                        ] else
                          const Text('Select account', style: TextStyle(fontSize: 13.5, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDuesLoan != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: AppColors.income.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 13, color: AppColors.income),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Deducts from ${_selectedDuesLoan!.person.name}\'s loan (Remaining: ${CurrencyFormatter.formatCents(_selectedDuesLoan!.remainingCents, symbol: currency.symbol)})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedDuesLoan = null);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(LucideIcons.x, size: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_selectedRepayDebtLoan != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              color: AppColors.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, size: 13, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Repays debt to ${_selectedRepayDebtLoan!.person.name} (Remaining debt: ${CurrencyFormatter.formatCents(_selectedRepayDebtLoan!.remainingCents, symbol: currency.symbol)})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setState(() => _selectedRepayDebtLoan = null);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(LucideIcons.x, size: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // If Transfer: Destination Account
          if (_selectedType == 'transfer') ...[
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            InkWell(
              onTap: () => _showAccountPicker(
                context,
                accounts.where((a) => a.id != _selectedAccountId).toList(),
                isToAccount: true,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'To Account',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                    const Spacer(),
                    if (selectedToAcc != null) ...[
                      Icon(IconHelper.getIcon(selectedToAcc.icon), size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        selectedToAcc.name,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                    ] else
                      const Text('Select destination', style: TextStyle(fontSize: 13.5, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],

          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),

          // Row 2: Date & Time Picker
          InkWell(
            onTap: () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (pickedDate != null && mounted) {
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_selectedDate),
                );
                if (pickedTime != null && mounted) {
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  });
                } else {
                  setState(() {
                    _selectedDate = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      _selectedDate.hour,
                      _selectedDate.minute,
                    );
                  });
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Date & Time',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDisplayDateTime(_selectedDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
          // If Dues: Return Due Date
          if (_selectedType == 'dues') ...[
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2040),
                );
                if (picked != null) {
                  setState(() => _returnDate = picked);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Return Date',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _returnDate != null
                          ? DateFormat('MMM d, yyyy').format(_returnDate!)
                          : 'Optional',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: _returnDate != null
                            ? (isDark ? Colors.white : const Color(0xFF111827))
                            : Colors.grey,
                      ),
                    ),
                    if (_returnDate != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() {
                          _returnDate = null;
                          _duesReminderOption = 'none';
                        }),
                        child: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
                      ),
                    ] else ...[
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight, size: 14, color: Colors.grey),
                    ],
                  ],
                ),
              ),
            ),
            if (_returnDate != null) ...[
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Reminder',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _duesReminderOption,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('No reminder')),
                          DropdownMenuItem(value: '1_day', child: Text('1 day before')),
                          DropdownMenuItem(value: '3_days', child: Text('3 days before')),
                          DropdownMenuItem(value: '1_week', child: Text('1 week before')),
                          DropdownMenuItem(value: '2_weeks', child: Text('2 weeks before')),
                          DropdownMenuItem(value: '1_month', child: Text('1 month before')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _duesReminderOption = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),

          // Row 3: Note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Note',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _noteController,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a note',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey.shade400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsAndBatchRow(bool isDark) {
    return Column(
      children: [
        if (!_showMoreOptions) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _showMoreOptions = true),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.tag, size: 13, color: isDark ? Colors.white54 : Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        'Add tags',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.editTransaction == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Save & add next',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: _saveAndAddAnother,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) => setState(() => _saveAndAddAnother = val),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.hash, size: 14, color: isDark ? Colors.white54 : Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'trip, work, grocery',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.editTransaction == null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: _saveAndAddAnother,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) => setState(() => _saveAndAddAnother = val),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNumericKeypad(ThemeData theme, bool isDark) {
    final buttonBg = isDark ? AppColors.darkSurfaceElevated : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], buttonBg, textColor),
        const SizedBox(height: 6),
        _buildKeypadRow(['4', '5', '6'], buttonBg, textColor),
        const SizedBox(height: 6),
        _buildKeypadRow(['7', '8', '9'], buttonBg, textColor),
        const SizedBox(height: 6),
        _buildKeypadRow(['.', '0', 'backspace'], buttonBg, textColor),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys, Color bg, Color textColor) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  if (key == 'backspace') {
                    _onKeypadBackspace();
                  } else {
                    _onKeypadTap(key);
                  }
                },
                onLongPress: key == 'backspace' ? _onKeypadClear : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.04),
                      width: 1,
                    ),
                  ),
                  child: key == 'backspace'
                      ? Icon(LucideIcons.delete, size: 20, color: textColor)
                      : Text(
                          key,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveButton(ThemeData theme, bool isDark, Color typeColor) {
    final rawAmount = _amountInput.isNotEmpty ? _amountInput : _amountController.text;
    final cents = CurrencyFormatter.parseAmountToCents(rawAmount) ?? 0;
    final hasAmount = cents > 0;

    String buttonText;
    if (widget.editTransaction != null) {
      buttonText = 'Update Transaction';
    } else if (!hasAmount) {
      buttonText = 'Enter an amount';
    } else if (_saveAndAddAnother) {
      buttonText = 'Save & Add Next';
    } else if (_selectedType == 'expense' && _selectedDuesLoan != null) {
      buttonText = 'Save & Deduct from ${_selectedDuesLoan!.person.name}';
    } else if (_selectedType == 'expense' && _selectedRepayDebtLoan != null) {
      buttonText = 'Save & Repay to ${_selectedRepayDebtLoan!.person.name}';
    } else {
      buttonText = _selectedType == 'expense'
          ? 'Save Expense'
          : _selectedType == 'income'
              ? 'Save Income'
              : _selectedType == 'transfer'
                  ? 'Save Transfer'
                  : _duesSubType == 'lent'
                      ? 'Record Money Given'
                      : 'Record Money Received';
    }

    final buttonBg = !hasAmount
        ? (isDark ? AppColors.darkSurfaceElevated : Colors.white)
        : (isDark ? Colors.white : const Color(0xFF18181B));

    final textColor = !hasAmount
        ? Colors.grey.shade500
        : (isDark ? const Color(0xFF18181B) : Colors.white);

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: buttonBg,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          onTap: hasAmount ? _saveTransaction : null,
          borderRadius: BorderRadius.circular(25),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: !hasAmount
                  ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2))
                  : null,
            ),
            child: Text(
              buttonText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
