import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/csv_json_export_import.dart';
import '../providers/settings_provider.dart';
import 'category_manager_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportFullBackup(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final accounts = await db.getAllAccounts();
      final categories = await db.getCategories();
      final transactions = await db.select(db.transactions).get();
      final budgets = await db.select(db.budgets).get();
      final goals = await db.select(db.goals).get();
      final rules = await db.select(db.merchantRules).get();

      final jsonBackup = CsvJsonExporter.exportFullBackupJson(
        accounts: accounts.map((a) => a.toJson()).toList(),
        categories: categories.map((c) => c.toJson()).toList(),
        transactions: transactions.map((t) => t.toJson()).toList(),
        budgets: budgets.map((b) => b.toJson()).toList(),
        goals: goals.map((g) => g.toJson()).toList(),
        merchantRules: rules.map((r) => r.toJson()).toList(),
      );

      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'fintrack_backup_$dateStr.fintrack';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonBackup);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/octet-stream', name: fileName)],
        subject: fileName,
        text: 'FinTrack Backup File ($fileName)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting backup: $e')),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['fintrack', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await CsvJsonExporter.readFileWithAutoEncoding(file);
        final backupData = CsvJsonExporter.parseBackupJson(content);

        if (backupData != null) {
          final txCount = (backupData['transactions'] as List?)?.length ?? 0;
          final accCount = (backupData['accounts'] as List?)?.length ?? 0;
          final catCount = (backupData['categories'] as List?)?.length ?? 0;

          // Confirm restore
          if (context.mounted) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(LucideIcons.fileUp, color: AppColors.primary, size: 22),
                    SizedBox(width: 10),
                    Expanded(child: Text('Restore FinTrack Backup?')),
                  ],
                ),
                content: Text(
                  'Found $txCount transactions, $accCount accounts, and $catCount categories in this .fintrack backup file.\n\n'
                  'Import and restore this data into FinTrack?',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('Restore Now'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              final db = ref.read(databaseProvider);
              final importRes = await CsvJsonExporter.importBackupData(db: db, data: backupData);

              if (importRes.detectedCurrencyCode != null) {
                final matched = AppConstants.supportedCurrencies.firstWhere(
                  (c) => c.code.toUpperCase() == importRes.detectedCurrencyCode!.toUpperCase(),
                  orElse: () => AppConstants.supportedCurrencies.first,
                );
                ref.read(currencyProvider.notifier).setCurrency(matched);
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Successfully restored ${importRes.transactionsCount} transactions & ${importRes.accountsCount} accounts from .fintrack backup!',
                    ),
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid FinTrack backup file format.')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing backup: $e')),
        );
      }
    }
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: AppConstants.supportedCurrencies.length,
                    itemBuilder: (context, index) {
                      final c = AppConstants.supportedCurrencies[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(c.symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                        title: Text(c.name),
                        subtitle: Text('${c.code} (${c.symbol})'),
                        onTap: () {
                          ref.read(currencyProvider.notifier).setCurrency(c);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose Theme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(LucideIcons.sun, color: AppColors.primary),
                  title: const Text('Light'),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.moon, color: AppColors.secondary),
                  title: const Text('Dark (Paylix Obsidian)'),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.smartphone, color: Colors.grey),
                  title: const Text('System Default'),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmSeedDemoData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed 3-Month Realistic Demo Data?'),
        content: const Text(
          'This will populate your database with accounts, transactions, scheduled bills, category budgets, and savings goals for testing and exploration.\n\nExisting data is preserved.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final seeder = ref.read(sampleDataSeederProvider);
              await seeder.seedRealisticDemoData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Realistic 3-month demo data generated!')),
                );
              }
            },
            child: const Text('Generate Demo Data'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final themeMode = ref.watch(themeModeProvider);

    final themeLabel = themeMode == ThemeMode.light
        ? 'Light'
        : themeMode == ThemeMode.system
            ? 'System'
            : 'Dark';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        toolbarHeight: 64,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 22),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: const Text('Settings & Preferences', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Section: Financial Management (Accounts, Goals, Categories)
          const Text('FINANCIAL MANAGEMENT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.landmark, color: AppColors.secondary, size: 22),
                  title: const Text('Accounts & Net Worth', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Cash, bank accounts, mobile wallets & cards', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () => context.push('/accounts'),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.piggyBank, color: AppColors.primary, size: 22),
                  title: const Text('Savings Goals', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Set targets & calculate monthly savings suggestions', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () => context.push('/goals'),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.shapes, color: AppColors.warning, size: 22),
                  title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Customize income and expense categories', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.repeat, color: AppColors.primary, size: 22),
                  title: const Text('Subscriptions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Track recurring services, streaming & memberships', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () => context.push('/subscriptions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section: General Preferences
          const Text('PREFERENCES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.coins, color: AppColors.primary, size: 22),
                  title: const Text('Default Currency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: Text('${currency.name} (${currency.symbol} ${currency.code})', style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () => _showCurrencyPicker(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.moon, color: AppColors.secondary, size: 22),
                  title: const Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: Text(themeLabel, style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
                  onTap: () => _showThemePicker(context, ref),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: const Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 22),
                  title: const Text('Strict Safe-to-Spend Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Deduct monthly goal savings targets from daily safe-to-spend allowance', style: TextStyle(fontSize: 13)),
                  value: ref.watch(includeGoalsInSafeToSpendProvider),
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    ref.read(includeGoalsInSafeToSpendProvider.notifier).setIncludeGoals(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section: Data & Backup
          const Text('DATA & BACKUP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.download, color: AppColors.secondary, size: 22),
                  title: const Text('Export FinTrack Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Save transactions, accounts, and budgets as a .fintrack file', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.share2, size: 18, color: Colors.grey),
                  onTap: () => _exportFullBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.upload, color: AppColors.primary, size: 22),
                  title: const Text('Restore FinTrack Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Import and restore data from a .fintrack backup file', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(LucideIcons.fileUp, size: 18, color: Colors.grey),
                  onTap: () => _importBackup(context, ref),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: const Icon(LucideIcons.cloud, color: Colors.grey, size: 22),
                  title: const Text('Google Drive Backup', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  subtitle: const Text('Optional cloud sync (Free & local-first)', style: TextStyle(fontSize: 13)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Local-First', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FinTrack operates 100% offline. File backup is ready above.')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Section: Demo Data Explorer
          const Text('TESTING & EXPLORATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(LucideIcons.sparkles, color: AppColors.primary, size: 24),
              title: const Text('Seed 3-Month Demo Data', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
              subtitle: const Text('Pre-fills realistic accounts, categories, charts, and budgets', style: TextStyle(fontSize: 13)),
              trailing: ElevatedButton(
                onPressed: () => _confirmSeedDemoData(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: const Text('Seed Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Section: Monetization / AdMob Information
          const Text('MONETIZATION & ADS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.shieldCheck, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Text('All Features Unlocked (Single Tier)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FinTrack is 100% free and offline. Non-intrusive banner ads help support active maintenance without interrupting transaction logging or locking core capabilities.',
                    style: TextStyle(fontSize: 13.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}
