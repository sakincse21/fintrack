import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/presentation/category_manager_screen.dart';
import '../../settings/providers/settings_provider.dart';
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
  final FocusNode _amountFocusNode = FocusNode();

  String _selectedType = 'expense'; // 'expense', 'income', 'transfer'
  int? _selectedCategoryId;
  int? _selectedAccountId;
  int? _selectedToAccountId; // for transfer
  DateTime _selectedDate = DateTime.now();
  String? _receiptImagePath;
  bool _saveAndAddAnother = false;
  bool _showAllCategories = false;
  bool _isAutoMatched = false;
  bool _showMoreOptions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) {
      _selectedType = widget.initialType!;
    }
    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _selectedType = tx.type;
      _amountController.text = (tx.amountCents / 100.0).toStringAsFixed(2);
      _noteController.text = tx.note;
      _selectedCategoryId = tx.categoryId;
      _selectedAccountId = tx.accountId;
      _selectedToAccountId = tx.toAccountId;
      _selectedDate = tx.date;
      _receiptImagePath = tx.receiptPath;
      _tagController.text = tx.tagIds;
      _showMoreOptions = true;
    }

    _noteController.addListener(_onNoteChanged);

    // Auto-focus amount on modal open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _amountController.dispose();
    _noteController.dispose();
    _tagController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onNoteChanged() async {
    final text = _noteController.text.trim();
    if (text.isEmpty || _selectedType == 'transfer') return;

    final db = ref.read(databaseProvider);
    final matchedCat = await db.findCategoryByMerchant(text);

    if (matchedCat != null && mounted) {
      setState(() {
        _selectedCategoryId = matchedCat.id;
        _isAutoMatched = true;
      });
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _receiptImagePath = picked.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking receipt: $e');
    }
  }

  Future<void> _saveTransaction() async {
    final cents = CurrencyFormatter.parseAmountToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          duration: Duration(seconds: 2),
        ),
      );
      _amountFocusNode.requestFocus();
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
          receiptPath: drift.Value(_receiptImagePath),
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
          receiptPath: drift.Value(_receiptImagePath),
          toAccountId: drift.Value(_selectedType == 'transfer' ? _selectedToAccountId : null),
        ),
      );

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
          _amountController.clear();
          _noteController.clear();
          _tagController.clear();
          _receiptImagePath = null;
          _isAutoMatched = false;
        });
        _amountFocusNode.requestFocus();
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
    final db = ref.watch(databaseProvider);
    final isDark = theme.brightness == Brightness.dark;

    final typeColor = _selectedType == 'income'
        ? AppColors.income
        : _selectedType == 'expense'
            ? AppColors.primary
            : AppColors.transfer;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle & Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.editTransaction != null ? 'Edit Transaction' : 'New Transaction',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_awesome_outlined, size: 20),
                          tooltip: 'Smart Quick Entry',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => NaturalVoiceInputDialog(
                                onParsed: (parsed) {
                                  setState(() {
                                    if (parsed.amountCents != null) {
                                      _amountController.text = (parsed.amountCents! / 100.0).toStringAsFixed(2);
                                    }
                                    _noteController.text = parsed.note;
                                    _selectedType = parsed.type;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. MINIMAL TYPE SELECTOR (Expense, Income, Transfer)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab('expense', 'Expense', AppColors.expense),
                        _buildTypeTab('income', 'Income', AppColors.income),
                        _buildTypeTab('transfer', 'Transfer', AppColors.transfer),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. BIG, CLEAN AMOUNT INPUT
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _amountFocusNode.hasFocus
                            ? typeColor
                            : theme.colorScheme.outline.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          currency.symbol,
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              filled: false,
                            ),
                          ),
                        ),
                        // Modifier chips (+100, +500)
                        Row(
                          children: [100, 500].map((amt) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: InkWell(
                                onTap: () {
                                  final cur = CurrencyFormatter.parseAmountToCents(_amountController.text) ?? 0;
                                  _amountController.text = ((cur + (amt * 100)) / 100.0).toStringAsFixed(2);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '+$amt',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 3. CLEAN CATEGORY GRID (Overflow-Proof)
                  if (_selectedType != 'transfer') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            if (_isAutoMatched) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Auto matched ✨',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        InkWell(
                          onTap: () => setState(() => _showAllCategories = !_showAllCategories),
                          child: Text(
                            _showAllCategories ? 'Fewer' : 'All Categories',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    StreamBuilder<List<Category>>(
                      stream: db.watchCategories(type: _selectedType),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        if (categories.isEmpty) return const SizedBox.shrink();

                        final displayList = _showAllCategories ? categories : categories.take(8).toList();

                        if (_selectedCategoryId == null && categories.isNotEmpty) {
                          _selectedCategoryId = categories.first.id;
                        }

                        final totalItemCount = displayList.length + (_showAllCategories ? 1 : 0);

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: totalItemCount,
                          itemBuilder: (context, index) {
                            if (index >= displayList.length) {
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      width: 1.5,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.plus, color: AppColors.primary, size: 22),
                                      SizedBox(height: 5),
                                      Text(
                                        '+ New',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final cat = displayList[index];
                            final isSelected = _selectedCategoryId == cat.id;
                            final catColor = Color(cat.colorValue);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = cat.id;
                                  _isAutoMatched = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? catColor.withValues(alpha: 0.18)
                                      : isDark
                                          ? AppColors.darkSurfaceElevated
                                          : AppColors.lightSurfaceElevated,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? catColor : Colors.transparent,
                                    width: 1.8,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      IconHelper.getIcon(cat.icon),
                                      color: catColor,
                                      size: 23,
                                    ),
                                    const SizedBox(height: 5),
                                    Flexible(
                                      child: Text(
                                        cat.name,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 4. NOTE & MERCHANT INPUT FIELD
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: 'Note or Merchant (e.g. Starbucks, Uber)',
                      prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: _receiptImagePath != null
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(_receiptImagePath!),
                                      width: 28,
                                      height: 28,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _receiptImagePath = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(1),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 9),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              tooltip: 'Attach Receipt',
                              onPressed: () => _pickReceipt(ImageSource.camera),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5. ACCOUNT & DATE ROW
                  Row(
                    children: [
                      // Account Selector
                      Expanded(
                        child: accountsAsync.when(
                          data: (rawAccounts) {
                            final seenIds = <int>{};
                            final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                            if (accounts.isEmpty) return const SizedBox.shrink();
                            if (_selectedAccountId == null || !accounts.any((a) => a.id == _selectedAccountId)) {
                              _selectedAccountId = accounts.first.id;
                            }

                            return DropdownButtonFormField<int>(
                              key: ValueKey('from_acc_$_selectedAccountId'),
                              initialValue: _selectedAccountId,
                              decoration: const InputDecoration(
                                labelText: 'Account',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: accounts.map((acc) {
                                return DropdownMenuItem<int>(
                                  value: acc.id,
                                  child: Row(
                                    children: [
                                      Icon(IconHelper.getIcon(acc.icon), size: 14),
                                      const SizedBox(width: 6),
                                      Text(acc.name, style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedAccountId = val;
                                    if (_selectedToAccountId == val) {
                                      final others = accounts.where((a) => a.id != val).toList();
                                      _selectedToAccountId = others.isNotEmpty ? others.first.id : null;
                                    }
                                  });
                                }
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // If Transfer: Destination Account; Else: Date Picker
                      if (_selectedType == 'transfer') ...[
                        Expanded(
                          child: accountsAsync.when(
                            data: (rawAccounts) {
                              final seenIds = <int>{};
                              final accounts = rawAccounts.where((a) => seenIds.add(a.id)).toList();
                              final toAccounts = accounts.where((a) => a.id != _selectedAccountId).toList();

                              if (toAccounts.isEmpty) {
                                return const InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'To Account',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Text('No other account', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                );
                              }

                              if (_selectedToAccountId == null || !toAccounts.any((a) => a.id == _selectedToAccountId)) {
                                _selectedToAccountId = toAccounts.first.id;
                              }

                              return DropdownButtonFormField<int>(
                                key: ValueKey('to_acc_${_selectedToAccountId}_from_$_selectedAccountId'),
                                initialValue: _selectedToAccountId,
                                decoration: const InputDecoration(
                                  labelText: 'To Account',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: toAccounts.map((acc) {
                                  return DropdownMenuItem<int>(
                                    value: acc.id,
                                    child: Row(
                                      children: [
                                        Icon(IconHelper.getIcon(acc.icon), size: 14),
                                        const SizedBox(width: 6),
                                        Text(acc.name, style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedToAccountId = val);
                                  }
                                },
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_outlined, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(_selectedDate),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // 6. EXPANDABLE MORE OPTIONS (Tags)
                  if (!_showMoreOptions) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _showMoreOptions = true),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add tags', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        hintText: 'Tags (e.g. #trip, #work, #grocery)',
                        prefixIcon: Icon(Icons.tag_rounded, size: 16),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 7. BATCH ENTRY TOGGLE
                  if (widget.editTransaction == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Save & add next', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Switch.adaptive(
                          value: _saveAndAddAnother,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) => setState(() => _saveAndAddAnother = val),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  // 8. SUBMIT ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: typeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        widget.editTransaction != null
                            ? 'Update'
                            : _saveAndAddAnother
                                ? 'Save & Add Next'
                                : 'Save Transaction',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String type, String label, Color color) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
