import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fintrack/core/utils/currency_formatter.dart';
import 'package:fintrack/core/utils/natural_input_parser.dart';
import 'package:fintrack/core/utils/date_utils.dart';
import 'package:fintrack/core/utils/csv_json_export_import.dart';
import 'package:fintrack/features/dashboard/presentation/widgets/balance_card.dart';
import 'package:fintrack/features/dashboard/presentation/widgets/cash_flow_card.dart';
import 'package:fintrack/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:fintrack/features/reports/providers/reports_provider.dart';
import 'package:fintrack/features/settings/presentation/category_manager_screen.dart';
import 'package:fintrack/features/settings/presentation/settings_screen.dart';
import 'package:fintrack/features/splash/presentation/splash_screen.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formatCents formats correctly with symbol and decimals', () {
      expect(CurrencyFormatter.formatCents(125000, symbol: '\$'), '\$1,250.00');
      expect(CurrencyFormatter.formatCents(500, symbol: '₹'), '₹5.00');
      expect(CurrencyFormatter.formatCents(0, symbol: '৳'), '৳0.00');
      expect(CurrencyFormatter.formatCents(-3500, symbol: '\$'), '-\$35.00');
    });

    test('formatCompact formats compact numbers correctly', () {
      expect(CurrencyFormatter.formatCompact(150000, symbol: '\$'), '\$1.5K');
      expect(CurrencyFormatter.formatCompact(250000000, symbol: '\$'), '\$2.5M');
      expect(CurrencyFormatter.formatCompact(4500, symbol: '\$'), '\$45');
    });

    test('parseAmountToCents parses string inputs reliably', () {
      expect(CurrencyFormatter.parseAmountToCents('12.50'), 1250);
      expect(CurrencyFormatter.parseAmountToCents('\$1,250.00'), 125000);
      expect(CurrencyFormatter.parseAmountToCents('200'), 20000);
      expect(CurrencyFormatter.parseAmountToCents(''), isNull);
    });
  });

  group('NaturalInputParser Tests', () {
    test('parses amount, note, and auto-matches category for dining', () {
      final res = NaturalInputParser.parse('200 for lunch');
      expect(res.amountCents, 20000);
      expect(res.note.toLowerCase(), 'lunch');
      expect(res.suggestedCategoryName, 'Food & Dining');
      expect(res.type, 'expense');
    });

    test('parses amount and grocery keyword', () {
      final res = NaturalInputParser.parse('₹450 grocery at walmart');
      expect(res.amountCents, 45000);
      expect(res.suggestedCategoryName, 'Groceries');
      expect(res.type, 'expense');
    });

    test('parses Uber ride transportation keyword', () {
      final res = NaturalInputParser.parse('Uber 35.50');
      expect(res.amountCents, 3550);
      expect(res.suggestedCategoryName, 'Transportation');
      expect(res.type, 'expense');
    });

    test('parses Salary as income', () {
      final res = NaturalInputParser.parse('Salary 5000');
      expect(res.amountCents, 500000);
      expect(res.suggestedCategoryName, 'Salary');
      expect(res.type, 'income');
    });
  });

  group('AppDateUtils Tests', () {
    test('DateRange generates valid dates', () {
      final range = DateRange.fromFilter(DateRangeFilter.thisMonth);
      expect(range.start.day, 1);
      expect(range.label, 'This Month');
    });

    test('formatRelative formats today correctly', () {
      final now = DateTime.now();
      expect(AppDateUtils.formatRelative(now), 'Today');
    });
  });

  group('CsvJsonExporter Tests', () {
    test('converts transactions to CSV properly', () {
      final items = [
        CsvExportData(
          date: 'Aug 31, 2026',
          account: 'Checking Bank',
          category: 'Food & Dining',
          type: 'expense',
          amount: 15.50,
          note: 'Coffee',
          tags: '#coffee',
        )
      ];

      final csv = CsvJsonExporter.transactionsToCsv(items);
      expect(csv.contains('Date,Account,Category,Type,Amount,Note,Tags'), isTrue);
      expect(csv.contains('Food & Dining'), isTrue);
      expect(csv.contains('15.50'), isTrue);
    });

    test('exports and parses native backup JSON', () {
      final jsonStr = CsvJsonExporter.exportFullBackupJson(
        accounts: [{'name': 'Cash'}],
        categories: [{'name': 'Food'}],
        transactions: [],
        budgets: [],
        goals: [],
        merchantRules: [],
      );

      final parsed = CsvJsonExporter.parseBackupJson(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!['app'], 'FinTrack');
      expect(parsed['accounts'], isNotEmpty);
    });

    test('parses external UUID-based JSON backup format and sanitizes null bytes', () {
      const externalBackupJsonWithNullBytes = '\u0000{\u0000"accounts": [{"name": "Cash", "currency": "BDT", "id": "acc-1"}], "categories": [{"name": "Food & Drinks", "id": "cat-1"}], "settings": [{"currency": "BDT"}], "transactions": [{"accountId": "acc-1", "type": "EXPENSE", "amount": 25.0, "title": "Chotpoti", "dateTime": 1788089520000, "categoryId": "cat-1", "id": "tx-1"}]}';

      final parsed = CsvJsonExporter.parseBackupJson(externalBackupJsonWithNullBytes);
      expect(parsed, isNotNull);
      expect(parsed!['accounts'], isNotEmpty);
      expect(parsed['categories'], isNotEmpty);
      expect(parsed['transactions'], isNotEmpty);

      final accounts = parsed['accounts'] as List;
      final txs = parsed['transactions'] as List;
      expect(accounts.first['name'], 'Cash');
      expect(txs.first['title'], 'Chotpoti');
      expect(txs.first['amount'], 25.0);
    });

    test('decodeBytesWithAutoEncoding accurately decodes UTF-16 LE bytes', () {
      const originalJson = '{"accounts": [{"name": "Cash", "id": "1"}], "transactions": []}';
      
      // Construct UTF-16 LE byte array with BOM [0xFF, 0xFE]
      final List<int> utf16LeBytes = [0xFF, 0xFE];
      for (final codeUnit in originalJson.codeUnits) {
        utf16LeBytes.add(codeUnit & 0xFF);
        utf16LeBytes.add((codeUnit >> 8) & 0xFF);
      }

      final decoded = CsvJsonExporter.decodeBytesWithAutoEncoding(utf16LeBytes);
      expect(decoded.contains('"Cash"'), isTrue);

      final parsed = CsvJsonExporter.parseBackupJson(decoded);
      expect(parsed, isNotNull);
      expect(parsed!['accounts'], isNotEmpty);
    });
  });

  group('Widget Tests', () {
    testWidgets('BalanceCard renders balance and currency correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: BalanceCard(
                totalBalanceCents: 250000,
                incomeCents: 500000,
                expenseCents: 200000,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TOTAL BALANCE'), findsOneWidget);
      expect(find.text('\$2,500.00'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('CashFlowCard renders income, expenses and savings rate correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CashFlowCard(
                incomeCents: 500000,
                expenseCents: 200000,
                netCents: 300000,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Net Savings'), findsOneWidget);
      expect(find.text('+60%'), findsOneWidget);
      expect(find.text('\$5,000.00'), findsOneWidget);
      expect(find.text('\$2,000.00'), findsOneWidget);
      expect(find.text('+\$3,000.00'), findsOneWidget);
    });

    testWidgets('SplashScreen renders FinTrack brand title and tagline', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoNavigate: false),
        ),
      );
      await tester.pump();

      expect(find.text('FinTrack'), findsOneWidget);
      expect(find.text('Smart Financial Tracking'), findsOneWidget);
    });

    testWidgets('QuickAddSheet renders in transfer mode without dropdown assertion errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuickAddSheet(initialType: 'transfer'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(QuickAddSheet), findsOneWidget);
    });

    testWidgets('CategoryManagerScreen renders with tabs and Add button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CategoryManagerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Manage Categories'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('SettingsScreen displays FinTrack backup options and no Ivy Wallet options', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Export FinTrack Backup'), findsOneWidget);
      expect(find.text('Restore FinTrack Backup'), findsOneWidget);
      expect(find.text('Restore from Ivy Wallet Backup'), findsNothing);
      expect(find.textContaining('Ivy Wallet'), findsNothing);
    });
  });

  group('FinTrack Backup Payload Tests', () {
    test('exportFullBackupJson generates valid FinTrack payload with .fintrack compatibility', () {
      final jsonStr = CsvJsonExporter.exportFullBackupJson(
        accounts: [{'id': 1, 'name': 'Checking'}],
        categories: [{'id': 1, 'name': 'Groceries'}],
        transactions: [{'id': 1, 'amountCents': 5000, 'type': 'expense'}],
        budgets: [],
        goals: [],
        merchantRules: [],
      );

      final parsed = CsvJsonExporter.parseBackupJson(jsonStr);
      expect(parsed, isNotNull);
      expect(parsed!['app'], 'FinTrack');
      expect(parsed['accounts'], isNotEmpty);
      expect(parsed['transactions'], isNotEmpty);
    });
  });

  group('Reports Analytics Filter Tests', () {
    test('ReportFilterNotifier manages filter state and active count correctly', () {
      final notifier = ReportFilterNotifier();
      expect(notifier.state.dateRangeFilter, DateRangeFilter.thisMonth);
      expect(notifier.state.activeFiltersCount, 0);

      // Filter by account
      notifier.setAccount(3);
      expect(notifier.state.accountId, 3);
      expect(notifier.state.activeFiltersCount, 1);

      // Filter by categories (multi-select)
      notifier.toggleCategory(10);
      notifier.toggleCategory(12);
      expect(notifier.state.selectedCategoryIds, {10, 12});
      expect(notifier.state.activeFiltersCount, 3);

      // Filter by type
      notifier.setType('expense');
      expect(notifier.state.selectedType, 'expense');
      expect(notifier.state.activeFiltersCount, 4);

      // Date range filter
      notifier.setFilter(DateRangeFilter.lastMonth);
      expect(notifier.state.dateRangeFilter, DateRangeFilter.lastMonth);
      expect(notifier.state.activeFiltersCount, 5);

      // Reset
      notifier.reset();
      expect(notifier.state.accountId, isNull);
      expect(notifier.state.selectedCategoryIds, isEmpty);
      expect(notifier.state.selectedType, 'all');
      expect(notifier.state.dateRangeFilter, DateRangeFilter.thisMonth);
      expect(notifier.state.activeFiltersCount, 0);
    });
  });
}
