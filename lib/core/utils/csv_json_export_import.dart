import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';

class CsvExportData {
  final String date;
  final String account;
  final String category;
  final String type;
  final double amount;
  final String note;
  final String tags;

  CsvExportData({
    required this.date,
    required this.account,
    required this.category,
    required this.type,
    required this.amount,
    required this.note,
    required this.tags,
  });
}

class ImportResult {
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final String? detectedCurrencyCode;

  ImportResult({
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    this.detectedCurrencyCode,
  });
}

class CsvJsonExporter {
  /// Converts transaction list to standard CSV string
  static String transactionsToCsv(List<CsvExportData> items) {
    final List<List<dynamic>> rows = [
      ['Date', 'Account', 'Category', 'Type', 'Amount', 'Note', 'Tags']
    ];

    for (final item in items) {
      rows.add([
        item.date,
        item.account,
        item.category,
        item.type,
        item.amount.toStringAsFixed(2),
        item.note,
        item.tags,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Exports full app data to a formatted JSON string for full local backup
  static String exportFullBackupJson({
    required List<Map<String, dynamic>> accounts,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> transactions,
    required List<Map<String, dynamic>> budgets,
    required List<Map<String, dynamic>> goals,
    required List<Map<String, dynamic>> merchantRules,
  }) {
    final payload = {
      'app': 'FinTrack',
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts,
      'categories': categories,
      'transactions': transactions,
      'budgets': budgets,
      'goals': goals,
      'merchant_rules': merchantRules,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Safely reads file contents with automatic UTF-8 / UTF-16LE / UTF-16BE / Latin-1 encoding detection
  static Future<String> readFileWithAutoEncoding(dynamic fileOrBytes) async {
    List<int> bytes;
    if (fileOrBytes is List<int>) {
      bytes = fileOrBytes;
    } else {
      bytes = await (fileOrBytes as dynamic).readAsBytes() as List<int>;
    }
    return decodeBytesWithAutoEncoding(bytes);
  }

  /// Decodes raw bytes with BOM and null-byte detection for UTF-16 LE, UTF-16 BE, UTF-8, Latin-1
  static String decodeBytesWithAutoEncoding(List<int> bytes) {
    if (bytes.isEmpty) return '';

    // UTF-16 LE BOM: 0xFF 0xFE
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      final buffer = StringBuffer();
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        final charCode = bytes[i] | (bytes[i + 1] << 8);
        if (charCode != 0) buffer.writeCharCode(charCode);
      }
      return sanitizeJsonString(buffer.toString());
    }

    // UTF-16 BE BOM: 0xFE 0xFF
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final buffer = StringBuffer();
      for (int i = 2; i + 1 < bytes.length; i += 2) {
        final charCode = (bytes[i] << 8) | bytes[i + 1];
        if (charCode != 0) buffer.writeCharCode(charCode);
      }
      return sanitizeJsonString(buffer.toString());
    }

    // UTF-8 BOM: 0xEF 0xBB 0xBF
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return sanitizeJsonString(utf8.decode(bytes.sublist(3), allowMalformed: true));
    }

    // UTF-16 LE without BOM (check if second byte is 0x00 and 4th byte is 0x00)
    if (bytes.length >= 4 && bytes[1] == 0x00 && bytes[3] == 0x00) {
      final buffer = StringBuffer();
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final charCode = bytes[i] | (bytes[i + 1] << 8);
        if (charCode != 0) buffer.writeCharCode(charCode);
      }
      return sanitizeJsonString(buffer.toString());
    }

    // UTF-16 BE without BOM (check if first byte is 0x00 and 3rd byte is 0x00)
    if (bytes.length >= 4 && bytes[0] == 0x00 && bytes[2] == 0x00) {
      final buffer = StringBuffer();
      for (int i = 0; i + 1 < bytes.length; i += 2) {
        final charCode = (bytes[i] << 8) | bytes[i + 1];
        if (charCode != 0) buffer.writeCharCode(charCode);
      }
      return sanitizeJsonString(buffer.toString());
    }

    // Standard UTF-8 with allowMalformed: true fallback to Latin-1
    try {
      final decoded = utf8.decode(bytes, allowMalformed: true);
      return sanitizeJsonString(decoded);
    } catch (_) {
      return sanitizeJsonString(latin1.decode(bytes));
    }
  }

  /// Sanitizes JSON text by stripping UTF-16 null bytes or BOMs
  static String sanitizeJsonString(String raw) {
    return raw
        .replaceAll('\uFEFF', '')
        .replaceAll('\uFFFE', '')
        .replaceAll('\u0000', '')
        .trim();
  }

  /// Parses and validates a JSON backup payload (FinTrack or external backup)
  static Map<String, dynamic>? parseBackupJson(String jsonString) {
    try {
      final clean = sanitizeJsonString(jsonString);
      final data = jsonDecode(clean);
      if (data is Map<String, dynamic>) {
        if (data['app'] == 'FinTrack' ||
            (data.containsKey('transactions') && data.containsKey('accounts'))) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Imports backup data into the SQLite database with UUID mapping and type resolution
  static Future<ImportResult> importBackupData({
    required AppDatabase db,
    required Map<String, dynamic> data,
  }) async {
    int accountsCreated = 0;
    int categoriesCreated = 0;
    int transactionsCreated = 0;
    String? detectedCurrency;

    // Detect currency from settings if present
    if (data['settings'] is List && (data['settings'] as List).isNotEmpty) {
      final s = (data['settings'] as List).first;
      if (s is Map && s['currency'] != null) {
        detectedCurrency = s['currency'].toString().toUpperCase();
      }
    }

    final isFinTrackNative = data['app'] == 'FinTrack';

    if (isFinTrackNative) {
      // 1. Native FinTrack Import
      final rawAccounts = data['accounts'] as List? ?? [];
      final rawCategories = data['categories'] as List? ?? [];
      final rawTransactions = data['transactions'] as List? ?? [];

      for (final a in rawAccounts) {
        if (a is Map<String, dynamic>) {
          await db.into(db.accounts).insertOnConflictUpdate(
                AccountsCompanion.insert(
                  id: a['id'] is int ? Value(a['id']) : const Value.absent(),
                  name: a['name']?.toString() ?? 'Account',
                  type: a['type']?.toString() ?? 'bank',
                  initialBalanceCents: Value(a['initialBalanceCents'] ?? 0),
                  currency: Value(a['currency']?.toString() ?? 'USD'),
                  icon: Value(a['icon']?.toString() ?? 'account_balance'),
                ),
              );
          accountsCreated++;
        }
      }

      for (final c in rawCategories) {
        if (c is Map<String, dynamic>) {
          await db.into(db.categories).insertOnConflictUpdate(
                CategoriesCompanion.insert(
                  id: c['id'] is int ? Value(c['id']) : const Value.absent(),
                  name: c['name']?.toString() ?? 'Category',
                  type: c['type']?.toString() ?? 'expense',
                  colorValue: Value(c['colorValue'] ?? 0xFF10B981),
                  icon: Value(c['icon']?.toString() ?? 'category'),
                  isDefault: Value(c['isDefault'] ?? false),
                ),
              );
          categoriesCreated++;
        }
      }

      for (final t in rawTransactions) {
        if (t is Map<String, dynamic>) {
          final dateStr = t['date']?.toString();
          final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

          await db.into(db.transactions).insert(
                TransactionsCompanion.insert(
                  accountId: t['accountId'] ?? 1,
                  toAccountId: Value(t['toAccountId']),
                  categoryId: Value(t['categoryId']),
                  amountCents: t['amountCents'] ?? 0,
                  type: t['type']?.toString() ?? 'expense',
                  note: Value(t['note']?.toString() ?? ''),
                  tagIds: Value(t['tagIds']?.toString() ?? ''),
                  date: dt,
                ),
              );
          transactionsCreated++;
        }
      }

      // Restore budgets if present
      final rawBudgets = data['budgets'] as List? ?? [];
      for (final b in rawBudgets) {
        if (b is Map<String, dynamic> && b['categoryId'] != null) {
          final startDateStr = b['startDate']?.toString();
          final sdt = startDateStr != null ? DateTime.tryParse(startDateStr) ?? DateTime.now() : DateTime.now();
          await db.into(db.budgets).insert(
                BudgetsCompanion.insert(
                  categoryId: b['categoryId'],
                  amountCents: b['amountCents'] ?? 0,
                  period: Value(b['period']?.toString() ?? 'monthly'),
                  startDate: sdt,
                  rolloverEnabled: Value(b['rolloverEnabled'] ?? false),
                ),
              );
        }
      }

      // Restore goals if present
      final rawGoals = data['goals'] as List? ?? [];
      for (final g in rawGoals) {
        if (g is Map<String, dynamic> && g['name'] != null) {
          final targetDateStr = g['targetDate']?.toString();
          final tdt = targetDateStr != null ? DateTime.tryParse(targetDateStr) ?? DateTime.now() : DateTime.now();
          await db.into(db.goals).insert(
                GoalsCompanion.insert(
                  name: g['name'].toString(),
                  targetAmountCents: g['targetAmountCents'] ?? 0,
                  currentAmountCents: Value(g['currentAmountCents'] ?? 0),
                  targetDate: tdt,
                  linkedAccountId: Value(g['linkedAccountId']),
                ),
              );
        }
      }

      // Restore merchant rules if present
      final rawRules = data['merchant_rules'] as List? ?? [];
      for (final r in rawRules) {
        final keyword = (r['keyword'] ?? r['pattern'])?.toString();
        final catId = r['categoryId'];
        if (keyword != null && catId is int) {
          await db.into(db.merchantRules).insertOnConflictUpdate(
                MerchantRulesCompanion.insert(
                  keyword: keyword,
                  categoryId: catId,
                ),
              );
        }
      }
    } else {
      // 2. External UUID-based Backup Import (e.g. Android MoneyManager / Ivy / Cashew)
      final accountUuidMap = <String, int>{};
      final categoryUuidMap = <String, int>{};

      final existingAccounts = await db.getAllAccounts();
      final existingCategories = await db.getCategories();

      // Accounts
      final rawAccounts = data['accounts'] as List? ?? [];
      for (final acc in rawAccounts) {
        if (acc is Map) {
          final uuid = acc['id']?.toString() ?? '';
          final name = acc['name']?.toString().trim() ?? 'Account';
          final currency = acc['currency']?.toString().toUpperCase() ?? detectedCurrency ?? 'BDT';
          detectedCurrency ??= currency;

          final lowerName = name.toLowerCase();
          final lowerIcon = (acc['icon'] ?? '').toString().toLowerCase();

          String accType = 'bank';
          String accIcon = 'account_balance';

          if (lowerName.contains('cash') || lowerIcon.contains('cash')) {
            accType = 'cash';
            accIcon = 'payments';
          } else if (lowerName.contains('bkash') ||
              lowerName.contains('nagad') ||
              lowerName.contains('rocket') ||
              lowerName.contains('upay') ||
              lowerName.contains('venmo') ||
              lowerIcon.contains('phone')) {
            accType = 'mobile_banking';
            accIcon = 'phone_android';
          } else if (lowerName.contains('card') ||
              lowerName.contains('credit') ||
              lowerIcon.contains('card')) {
            accType = 'card';
            accIcon = 'credit_card';
          }

          final match = existingAccounts.where((a) => a.name.toLowerCase() == lowerName).firstOrNull;

          if (match != null) {
            accountUuidMap[uuid] = match.id;
          } else {
            final newId = await db.into(db.accounts).insert(
                  AccountsCompanion.insert(
                    name: name,
                    type: accType,
                    currency: Value(currency),
                    icon: Value(accIcon),
                    initialBalanceCents: const Value(0),
                  ),
                );
            accountUuidMap[uuid] = newId;
            existingAccounts.add(Account(
              id: newId,
              name: name,
              type: accType,
              currency: currency,
              icon: accIcon,
              initialBalanceCents: 0,
              isArchived: false,
            ));
            accountsCreated++;
          }
        }
      }

      // Categories
      final rawCategories = data['categories'] as List? ?? [];
      for (final cat in rawCategories) {
        if (cat is Map) {
          final uuid = cat['id']?.toString() ?? '';
          final name = cat['name']?.toString().trim() ?? 'Category';
          final lowerName = name.toLowerCase();

          final colorRaw = cat['color'];
          int colorVal = 0xFF10B981;
          if (colorRaw is int) {
            colorVal = colorRaw < 0 ? (colorRaw & 0xFFFFFFFF) : colorRaw;
          }

          final rawIcon = (cat['icon'] ?? '').toString().toLowerCase();
          String mappedIcon = 'category';

          if (rawIcon.contains('food') || rawIcon.contains('drink') || lowerName.contains('food')) {
            mappedIcon = 'restaurant';
          } else if (rawIcon.contains('transport') || lowerName.contains('transport')) {
            mappedIcon = 'directions_car';
          } else if (rawIcon.contains('shop') || rawIcon.contains('cloth') || lowerName.contains('shopping')) {
            mappedIcon = 'shopping_bag';
          } else if (rawIcon.contains('bill') || rawIcon.contains('fee') || lowerName.contains('bill')) {
            mappedIcon = 'receipt_long';
          } else if (rawIcon.contains('house') || rawIcon.contains('home') || rawIcon.contains('room')) {
            mappedIcon = 'home';
          } else if (rawIcon.contains('edu') || lowerName.contains('education')) {
            mappedIcon = 'school';
          } else if (rawIcon.contains('loan') || lowerName.contains('loan')) {
            mappedIcon = 'account_balance';
          }

          final match = existingCategories.where((c) => c.name.toLowerCase() == lowerName).firstOrNull;

          if (match != null) {
            categoryUuidMap[uuid] = match.id;
          } else {
            final newId = await db.into(db.categories).insert(
                  CategoriesCompanion.insert(
                    name: name,
                    type: 'expense',
                    colorValue: Value(colorVal),
                    icon: Value(mappedIcon),
                    isDefault: const Value(false),
                  ),
                );
            categoryUuidMap[uuid] = newId;
            existingCategories.add(Category(
              id: newId,
              name: name,
              type: 'expense',
              colorValue: colorVal,
              icon: mappedIcon,
              isDefault: false,
            ));
            categoriesCreated++;
          }
        }
      }

      // Transactions
      final rawTransactions = data['transactions'] as List? ?? [];
      final defaultAccountId = accountUuidMap.values.isNotEmpty
          ? accountUuidMap.values.first
          : (existingAccounts.isNotEmpty ? existingAccounts.first.id : 1);

      for (final tx in rawTransactions) {
        if (tx is Map) {
          final rawType = (tx['type'] ?? 'EXPENSE').toString().toUpperCase();
          String txType = 'expense';
          if (rawType == 'INCOME') {
            txType = 'income';
          } else if (rawType == 'TRANSFER') {
            txType = 'transfer';
          }

          final rawAmount = tx['amount'];
          double amountDouble = (rawAmount is num)
              ? rawAmount.toDouble()
              : (double.tryParse(rawAmount?.toString() ?? '') ?? 0.0);
          int amountCents = (amountDouble * 100).round();

          final rawDt = tx['dateTime'] ?? tx['date'];
          DateTime txDate = DateTime.now();
          if (rawDt is int) {
            txDate = DateTime.fromMillisecondsSinceEpoch(rawDt);
          } else if (rawDt is String) {
            final intParsed = int.tryParse(rawDt);
            txDate = intParsed != null
                ? DateTime.fromMillisecondsSinceEpoch(intParsed)
                : (DateTime.tryParse(rawDt) ?? DateTime.now());
          }

          final note = (tx['title'] ?? tx['note'] ?? '').toString().trim();
          final accId = accountUuidMap[tx['accountId']?.toString()] ?? defaultAccountId;
          final toAccId = tx['toAccountId'] != null ? accountUuidMap[tx['toAccountId']?.toString()] : null;
          final catId = tx['categoryId'] != null ? categoryUuidMap[tx['categoryId']?.toString()] : null;

          await db.into(db.transactions).insert(
                TransactionsCompanion.insert(
                  accountId: accId,
                  toAccountId: Value(toAccId),
                  categoryId: Value(catId),
                  amountCents: amountCents,
                  type: txType,
                  note: Value(note),
                  date: txDate,
                ),
              );
          transactionsCreated++;
        }
      }
    }

    return ImportResult(
      accountsCount: accountsCreated,
      categoriesCount: categoriesCreated,
      transactionsCount: transactionsCreated,
      detectedCurrencyCode: detectedCurrency,
    );
  }
}
