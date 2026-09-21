import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../settings/providers/settings_provider.dart';
import 'widgets/person_picker.dart';

class AddLoanSheet extends ConsumerStatefulWidget {
  const AddLoanSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddLoanSheet(),
    );
  }

  @override
  ConsumerState<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends ConsumerState<AddLoanSheet> {
  String _type = 'lent'; // 'lent' or 'borrowed'
  Person? _selectedPerson;
  final _amountController = TextEditingController();
  int? _selectedAccountId;
  DateTime? _dueDate;
  String _reminderOption = 'none';
  final _noteController = TextEditingController();
  bool _isSaving = false;

  final List<Map<String, String>> _reminderOptions = [
    {'value': 'none', 'label': 'No reminder'},
    {'value': '1_day', 'label': '1 day before'},
    {'value': '3_days', 'label': '3 days before'},
    {'value': '1_week', 'label': '1 week before'},
    {'value': '2_weeks', 'label': '2 weeks before'},
    {'value': '1_month', 'label': '1 month before'},
  ];

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
    if (_selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person')),
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
      await db.insertLoan(
        LoansCompanion.insert(
          personId: _selectedPerson!.id,
          type: _type,
          amountCents: amountCents,
          accountId: _selectedAccountId!,
          createdAt: DateTime.now(),
          dueDate: drift.Value(_dueDate),
          reminderOption: drift.Value(_reminderOption),
          note: drift.Value(_noteController.text.isEmpty ? null : _noteController.text),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _type == 'lent'
                  ? 'Money given to ${_selectedPerson!.name} recorded'
                  : 'Money received from ${_selectedPerson!.name} recorded',
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
            const Text(
              'New Loan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Type toggle
            _buildTypeToggle(isDark),
            const SizedBox(height: 20),

            // Person picker
            _buildPersonPicker(isDark),
            const SizedBox(height: 16),

            // Amount
            _buildAmountField(currency),
            const SizedBox(height: 16),

            // Account selector
            accountsAsync.when(
              data: (accounts) => _buildAccountSelector(accounts, isDark),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Due date
            _buildDueDatePicker(isDark),

            // Reminder (only if due date is set)
            if (_dueDate != null) ...[
              const SizedBox(height: 16),
              _buildReminderPicker(isDark),
            ],

            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. For dinner, rent share...',
                prefixIcon: const Icon(LucideIcons.fileText, size: 18),
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
                    : Text(
                        _type == 'lent' ? 'Record Money Given' : 'Record Money Received',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _type = 'lent'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _type == 'lent'
                    ? AppColors.expense.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkSurfaceElevated : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _type == 'lent' ? AppColors.expense : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.arrowUpRight,
                    color: _type == 'lent' ? AppColors.expense : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Money Given',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _type == 'lent' ? AppColors.expense : Colors.grey,
                    ),
                  ),
                  Text(
                    'I gave money',
                    style: TextStyle(
                      fontSize: 11,
                      color: _type == 'lent' ? AppColors.expense.withValues(alpha: 0.7) : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _type = 'borrowed'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _type == 'borrowed'
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkSurfaceElevated : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _type == 'borrowed' ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.arrowDownLeft,
                    color: _type == 'borrowed' ? AppColors.primary : Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Money Received',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _type == 'borrowed' ? AppColors.primary : Colors.grey,
                    ),
                  ),
                  Text(
                    'I received money',
                    style: TextStyle(
                      fontSize: 11,
                      color: _type == 'borrowed' ? AppColors.primary.withValues(alpha: 0.7) : Colors.grey[500],
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

  Widget _buildPersonPicker(bool isDark) {
    return InkWell(
      onTap: () async {
        final person = await PersonPicker.show(context, ref);
        if (person != null) {
          setState(() => _selectedPerson = person);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.user, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: _selectedPerson != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPerson!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        if (_selectedPerson!.phone != null && _selectedPerson!.phone!.isNotEmpty)
                          Text(
                            _selectedPerson!.phone!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                      ],
                    )
                  : Text(
                      'Select person',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(CurrencyInfo currency) {
    return TextField(
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
    );
  }

  Widget _buildAccountSelector(List<Account> accounts, bool isDark) {
    // Auto-select first account if none selected
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final selectedAcc = accounts.where((a) => a.id == _selectedAccountId).firstOrNull;

    return InkWell(
      onTap: () => _showAccountPicker(context, accounts, isDark),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.wallet, size: 18, color: Colors.grey[600]),
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
              _type == 'lent' ? 'From' : 'To',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey[400]),
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
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.wallet, size: 18),
                ),
                title: Text(
                  acc.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
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

  Widget _buildDueDatePicker(bool isDark) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime(2040),
        );
        if (picked != null) {
          setState(() => _dueDate = picked);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.calendar, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dueDate != null
                    ? 'Due: ${DateFormat('MMM d, yyyy').format(_dueDate!)}'
                    : 'Set due date (optional)',
                style: TextStyle(
                  fontWeight: _dueDate != null ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 15,
                  color: _dueDate != null ? null : Colors.grey[500],
                ),
              ),
            ),
            if (_dueDate != null)
              GestureDetector(
                onTap: () => setState(() {
                  _dueDate = null;
                  _reminderOption = 'none';
                }),
                child: Icon(LucideIcons.x, size: 16, color: Colors.grey[400]),
              )
            else
              Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderPicker(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppColors.darkBorder : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.bell, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reminderOption,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: _reminderOptions
                    .map((opt) => DropdownMenuItem(
                          value: opt['value'],
                          child: Text(opt['label']!),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _reminderOption = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

