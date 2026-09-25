import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/default_categories.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});

  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Add / Edit Category Modal Sheet ---
  void _showAddEditCategorySheet({Category? existing, required String type}) {
    final db = ref.read(databaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: existing?.name ?? '');

    int selectedColorValue = existing?.colorValue ?? AppColors.categoryPalette.first.toARGB32();
    String selectedIconKey = existing?.icon ?? (type == 'income' ? 'account_balance_wallet' : 'category');

    final availableIcons = IconHelper.iconMap.keys.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final previewColor = Color(selectedColorValue);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing != null ? 'Edit Category' : 'New ${type.toUpperCase()} Category',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Live Preview Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: previewColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: previewColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Center(
                              child: Icon(
                                IconHelper.getIcon(selectedIconKey),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'Category Name',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  type == 'income' ? 'Income Category' : 'Expense Category',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Name Field
                    TextField(
                      controller: nameController,
                      style: const TextStyle(fontSize: 15.5),
                      decoration: InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Subscriptions, Gym, Coffee',
                        prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 20),

                    // Color Picker Swatches
                    const Text('Category Color', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppColors.categoryPalette.map((c) {
                        final colorArgb = c.toARGB32();
                        final isSelected = colorArgb == selectedColorValue;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedColorValue = colorArgb),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3.0)
                                  : Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.0),
                            ),
                            child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Icon Picker Grid
                    const Text('Category Icon', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Container(
                      height: 160,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: GridView.builder(
                        itemCount: availableIcons.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          final iconKey = availableIcons[index];
                          final isSelected = iconKey == selectedIconKey;

                          return InkWell(
                            onTap: () => setModalState(() => selectedIconKey = iconKey),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected ? Border.all(color: AppColors.primary, width: 2.0) : null,
                              ),
                              child: Icon(
                                IconHelper.getIcon(iconKey),
                                size: 22,
                                color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;

                              if (existing != null) {
                                await (db.update(db.categories)..where((c) => c.id.equals(existing.id))).write(
                                  CategoriesCompanion(
                                    name: drift.Value(name),
                                    colorValue: drift.Value(selectedColorValue),
                                    icon: drift.Value(selectedIconKey),
                                  ),
                                );
                              } else {
                                await db.into(db.categories).insert(
                                  CategoriesCompanion.insert(
                                    name: name,
                                    type: type,
                                    colorValue: drift.Value(selectedColorValue),
                                    icon: drift.Value(selectedIconKey),
                                    isDefault: const drift.Value(false),
                                  ),
                                );
                              }
                              if (context.mounted) Navigator.pop(sheetContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              existing != null ? 'Save Changes' : 'Create Category',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Delete Category with Transaction Transfer Protection ---
  Future<void> _confirmDeleteCategory(Category category) async {
    final db = ref.read(databaseProvider);
    final txCount = await db.getCategoryTransactionCount(category.id);

    if (!mounted) return;

    if (txCount == 0) {
      // 1. Direct Delete Confirmation (No transactions attached)
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.delete_outline_rounded, color: AppColors.expense, size: 22),
              SizedBox(width: 10),
              Text('Delete Category?'),
            ],
          ),
          content: Text('Are you sure you want to delete "${category.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await db.deleteCategory(category.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${category.name}" deleted.')),
          );
        }
      }
    } else {
      // 2. Cannot delete directly: Offer instant transfer of all transactions to another category
      final otherCategories = await db.getCategories(type: category.type);
      final validDestinationCategories = otherCategories.where((c) => c.id != category.id).toList();

      if (!mounted) return;

      if (validDestinationCategories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete "${category.name}" because it has $txCount transactions and no other ${category.type} category exists to transfer to. Create another category first.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      int selectedTargetCatId = validDestinationCategories.first.id;

      final transferAndDeleted = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 22),
                  SizedBox(width: 10),
                  Expanded(child: Text('Transfer & Delete Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                        color: AppColors.expense.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.expense, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '"${category.name}" has $txCount active transaction${txCount == 1 ? '' : 's'}.',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.expense),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'To protect your financial history, choose a destination category to reassign all transactions to before deleting:',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<int>(
                      key: ValueKey('transfer_target_cat_$selectedTargetCatId'),
                      initialValue: selectedTargetCatId,
                      decoration: const InputDecoration(
                        labelText: 'Transfer All Transactions To',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: validDestinationCategories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(IconHelper.getIcon(c.icon), size: 16),
                              const SizedBox(width: 8),
                              Text(c.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedTargetCatId = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
                  child: const Text('Transfer & Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ),
      );

      if (transferAndDeleted == true) {
        await db.reassignCategoryTransactions(category.id, selectedTargetCatId);
        await db.deleteCategory(category.id);

        final targetCategory = validDestinationCategories.firstWhere((c) => c.id == selectedTargetCatId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reassigned $txCount transactions to "${targetCategory.name}" and deleted "${category.name}".'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
        actions: [
          TextButton.icon(
            onPressed: () {
              final type = _tabController.index == 0 ? 'expense' : 'income';
              _showAddEditCategorySheet(type: type);
            },
            icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
            label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14)),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(db, 'expense'),
          _buildCategoryList(db, 'income'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final type = _tabController.index == 0 ? 'expense' : 'income';
          _showAddEditCategorySheet(type: type);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text('New Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildCategoryList(AppDatabase db, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<CategoryWithCount>>(
      stream: db.watchCategoriesWithCounts(type: type),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No $type categories yet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditCategorySheet(type: type),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('Add $type category'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final cat = item.category;
            final count = item.transactionCount;

            return RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    width: 1.0,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  onTap: () => _showAddEditCategorySheet(existing: cat, type: type),
                  leading: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Icon(
                        IconHelper.getIcon(cat.icon),
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      count == 1 ? '1 transaction' : '$count transactions',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Category',
                        onPressed: () => _showAddEditCategorySheet(existing: cat, type: type),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
                        tooltip: 'Delete Category',
                        onPressed: () => _confirmDeleteCategory(cat),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
