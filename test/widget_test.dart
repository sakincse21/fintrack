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
import 'package:fintrack/core/database/database.dart';
import 'package:fintrack/features/dashboard/presentation/widgets/safe_to_spend_card.dart';
import 'package:fintrack/features/dashboard/providers/safe_to_spend_provider.dart';
import 'package:fintrack/features/milestones/presentation/widgets/milestone_celebration_dialog.dart';
import 'package:fintrack/features/milestones/providers/milestones_provider.dart';
import 'package:fintrack/features/budgets/presentation/budgets_screen.dart';
import 'package:fintrack/features/budgets/providers/budgets_provider.dart';
import 'package:fintrack/features/reports/presentation/reports_screen.dart';
import 'package:fintrack/features/recurring/providers/recurring_provider.dart';
import 'package:fintrack/features/accounts/providers/accounts_provider.dart';
import 'package:fintrack/features/transactions/providers/transactions_provider.dart';
import 'package:fintrack/features/streaks/presentation/widgets/streak_detail_sheet.dart';
import 'package:fintrack/features/subscriptions/presentation/subscriptions_screen.dart';
import 'package:fintrack/features/transactions/presentation/widgets/transaction_detail_dialog.dart';
import 'package:fintrack/features/transactions/presentation/transactions_screen.dart';

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

    testWidgets('QuickAddSheet renders segmented type selector, category pills, details card, and keypad', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountsListProvider.overrideWith(
              (ref) => Stream.value([
                const Account(
                  id: 1,
                  name: 'Checking Account',
                  type: 'bank',
                  initialBalanceCents: 100000,
                  currency: 'USD',
                  icon: 'account_balance',
                  isArchived: false,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuickAddSheet(initialType: 'expense'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Segmented control options
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);

      // Category section is present with Add New action (replacing Manage)
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('Add New'), findsWidgets);

      // Details card rows are present
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Date & Time'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);

      // Smart Quick Entry is present, Voice option is removed
      expect(find.text('Smart Quick Entry'), findsOneWidget);
      expect(find.text('Voice'), findsNothing);

      // Custom numeric keypad keys are present
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('.'), findsOneWidget);

      // Initial CTA button state when amount is 0
      expect(find.text('Enter an amount'), findsOneWidget);

      // Tapping keypad updates hero amount and button state
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      expect(find.text('Save Expense'), findsOneWidget);
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

      // Filter by account (multi-select)
      notifier.setAccount(3);
      expect(notifier.state.accountId, 3);
      expect(notifier.state.selectedAccountIds, {3});
      expect(notifier.state.activeFiltersCount, 1);

      notifier.toggleAccount(5);
      expect(notifier.state.selectedAccountIds, {3, 5});
      expect(notifier.state.activeFiltersCount, 2);

      notifier.toggleAccount(3);
      expect(notifier.state.selectedAccountIds, {5});
      expect(notifier.state.activeFiltersCount, 1);

      // Filter by categories (multi-select)
      notifier.toggleCategory(10);
      notifier.toggleCategory(12);
      expect(notifier.state.selectedCategoryIds, {10, 12});
      expect(notifier.state.activeFiltersCount, 3);

      // Filter by transfer type
      notifier.setType('transfer');
      expect(notifier.state.selectedType, 'transfer');
      expect(notifier.state.activeFiltersCount, 4);

      // Filter by expense type
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
      expect(notifier.state.selectedAccountIds, isEmpty);
      expect(notifier.state.selectedCategoryIds, isEmpty);
      expect(notifier.state.selectedType, 'all');
      expect(notifier.state.dateRangeFilter, DateRangeFilter.thisMonth);
      expect(notifier.state.activeFiltersCount, 0);
    });
  });

  group('Daily Logging Streak Tests', () {
    testWidgets('StreakDetailSheet displays streak info, best, and grace days correctly', (tester) async {
      const streak = StreakStateData(
        id: 1,
        currentStreak: 12,
        longestStreak: 25,
        lastLoggedDate: '2026-09-07',
        graceMissesUsed: 1,
        graceMissesMonth: '2026-09',
        freezeAvailable: 1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakDetailSheet(streak: streak),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('12 Day Streak!'), findsOneWidget);
      expect(find.text('25 Days'), findsOneWidget);
      expect(find.text('1 used this month'), findsOneWidget);
    });
  });

  group('Safe to Spend Tests', () {
    test('SafeToSpendData calculates remainingPercentage and tiers correctly', () {
      // Tier 1: > 20% remaining
      const dataGreen = SafeToSpendData(
        safeToSpendCents: 80000,
        totalBudgetedCents: 100000,
        totalSpentCents: 15000,
        upcomingBillsCents: 5000,
        goalCommitmentsCents: 0,
        hasBudgets: true,
        isStrict: false,
      );
      expect(dataGreen.remainingPercentage, 0.80);
      expect(dataGreen.remainingPercentage > 0.20, isTrue);

      // Tier 2: <= 20% remaining
      const dataAmber = SafeToSpendData(
        safeToSpendCents: 15000,
        totalBudgetedCents: 100000,
        totalSpentCents: 75000,
        upcomingBillsCents: 10000,
        goalCommitmentsCents: 0,
        hasBudgets: true,
        isStrict: false,
      );
      expect(dataAmber.remainingPercentage, 0.15);
      expect(dataAmber.remainingPercentage <= 0.20 && dataAmber.safeToSpendCents >= 0, isTrue);

      // Tier 3: Overspent (negative)
      const dataRed = SafeToSpendData(
        safeToSpendCents: -5000,
        totalBudgetedCents: 100000,
        totalSpentCents: 105000,
        upcomingBillsCents: 0,
        goalCommitmentsCents: 0,
        hasBudgets: true,
        isStrict: false,
      );
      expect(dataRed.safeToSpendCents < 0, isTrue);
    });

    testWidgets('SafeToSpendCard renders hero amount and status pill', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            safeToSpendProvider.overrideWithValue(
              const AsyncValue.data(
                SafeToSpendData(
                  safeToSpendCents: 45000,
                  totalBudgetedCents: 100000,
                  totalSpentCents: 40000,
                  upcomingBillsCents: 15000,
                  goalCommitmentsCents: 0,
                  hasBudgets: true,
                  isStrict: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SafeToSpendCard(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SAFE TO SPEND'), findsOneWidget);
      expect(find.textContaining('450'), findsWidgets);
      expect(find.text('left to spend this month'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
    });

    testWidgets('SafeToSpendCard with isBudgetsScreen: true hides navigation header', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            safeToSpendProvider.overrideWithValue(
              const AsyncValue.data(
                SafeToSpendData(
                  safeToSpendCents: 45000,
                  totalBudgetedCents: 100000,
                  totalSpentCents: 40000,
                  upcomingBillsCents: 15000,
                  goalCommitmentsCents: 0,
                  hasBudgets: true,
                  isStrict: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SafeToSpendCard(isBudgetsScreen: true),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SAFE TO SPEND'), findsOneWidget);
      expect(find.text('Budgets'), findsNothing);
    });
  });

  group('Milestones Celebrations Tests', () {
    test('kKnownMilestones contains all key milestone definitions', () {
      expect(kKnownMilestones.containsKey('first_transaction'), isTrue);
      expect(kKnownMilestones.containsKey('streak_7'), isTrue);
      expect(kKnownMilestones.containsKey('streak_30'), isTrue);
      expect(kKnownMilestones.containsKey('streak_100'), isTrue);
      expect(kKnownMilestones.containsKey('first_goal'), isTrue);
      expect(kKnownMilestones.containsKey('budget_under_month_1'), isTrue);
    });

    testWidgets('MilestoneCelebrationDialog displays milestone title and dismisses', (tester) async {
      bool dismissed = false;
      final milestone = kKnownMilestones['streak_7']!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MilestoneCelebrationDialog(
              milestone: milestone,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('MILESTONE ACHIEVED'), findsOneWidget);
      expect(find.text(milestone.title), findsOneWidget);
      expect(find.text(milestone.description), findsOneWidget);

      await tester.tap(find.text('Nice! 🎉'));
      expect(dismissed, isTrue);
    });
  });

  group('Subscriptions Feature Tests', () {
    test('SubscriptionItem.normalizeToMonthly normalizes frequencies correctly', () {
      // Monthly
      expect(SubscriptionItem.normalizeToMonthly(1500, 'monthly'), 1500);

      // Weekly: $10/week * 4.333 = $43.33 -> 4333 cents
      expect(SubscriptionItem.normalizeToMonthly(1000, 'weekly'), 4333);

      // Yearly: $120/year / 12 = $10 -> 1000 cents
      expect(SubscriptionItem.normalizeToMonthly(12000, 'yearly'), 1000);

      // Daily: $1/day * 30 = $30 -> 3000 cents
      expect(SubscriptionItem.normalizeToMonthly(100, 'daily'), 3000);
    });

    test('SubscriptionItem.checkUnused detects overdue subscriptions beyond 1 cycle', () {
      final now = DateTime.now();

      // Future run date is NOT unused
      final futureDate = now.add(const Duration(days: 5));
      expect(SubscriptionItem.checkUnused(futureDate, 'monthly'), isFalse);

      // Monthly overdue by 10 days is NOT unused (> 30 days needed)
      final past10Days = now.subtract(const Duration(days: 10));
      expect(SubscriptionItem.checkUnused(past10Days, 'monthly'), isFalse);

      // Monthly overdue by 35 days IS unused (> 30 days)
      final past35Days = now.subtract(const Duration(days: 35));
      expect(SubscriptionItem.checkUnused(past35Days, 'monthly'), isTrue);

      // Weekly overdue by 8 days IS unused (> 7 days)
      final past8Days = now.subtract(const Duration(days: 8));
      expect(SubscriptionItem.checkUnused(past8Days, 'weekly'), isTrue);
    });

    testWidgets('SubscriptionsScreen renders title and empty state properly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionsProvider.overrideWithValue(
              AsyncValue.data(
                SubscriptionsSummary(
                  items: [],
                  totalMonthlyCents: 0,
                  activeCount: 0,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('No Subscriptions Tracked Yet'), findsOneWidget);
    });
  });

  group('Settings Screen Navigation Tests', () {
    testWidgets('SettingsScreen contains Subscriptions and Strict Safe-to-Spend switch', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Subscriptions'), findsOneWidget);
      expect(find.text('Strict Safe-to-Spend Mode'), findsOneWidget);
    });
  });

  group('Budgets and Reports Integration Tests', () {
    testWidgets('BudgetsScreen renders SafeToSpendCard at the top', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            budgetsWithProgressProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            safeToSpendProvider.overrideWithValue(
              const AsyncValue.data(
                SafeToSpendData(
                  safeToSpendCents: 52000,
                  totalBudgetedCents: 120000,
                  totalSpentCents: 68000,
                  upcomingBillsCents: 0,
                  goalCommitmentsCents: 0,
                  hasBudgets: true,
                  isStrict: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: BudgetsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SafeToSpendCard), findsOneWidget);
      expect(find.text('SAFE TO SPEND'), findsOneWidget);
      expect(find.text('No budgets set for this month'), findsOneWidget);
    });

    testWidgets('ReportsScreen filter bar displays Transfer flow type and multi-select filters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fullAnalyticsProvider.overrideWith(
              (ref) => Stream.value(
                FullAnalyticsReport(
                  dateRange: DateRange(
                    start: DateTime(2026, 9, 1),
                    end: DateTime(2026, 9, 30),
                    label: 'This Month',
                  ),
                  totalIncomeCents: 200000,
                  totalExpenseCents: 80000,
                  totalTransferCents: 15000,
                  netSavingsCents: 120000,
                  overallSavingsRate: 60.0,
                  monthlyTrends: [],
                  categoryBreakdowns: [],
                  momComparison: MonthOverMonthComparison(
                    currentMonthIncomeCents: 200000,
                    currentMonthExpenseCents: 80000,
                    lastMonthIncomeCents: 180000,
                    lastMonthExpenseCents: 90000,
                  ),
                  tagBreakdowns: [],
                  accountBreakdowns: [],
                  topMerchants: [],
                  dayOfWeekSpends: [],
                  timeOfMonthSpends: [],
                ),
              ),
            ),
            accountsListProvider.overrideWith(
              (ref) => Stream.value([
                const Account(
                  id: 1,
                  name: 'Checking Account',
                  type: 'bank',
                  initialBalanceCents: 100000,
                  currency: 'USD',
                  icon: 'account_balance',
                  isArchived: false,
                ),
                const Account(
                  id: 2,
                  name: 'Cash Wallet',
                  type: 'cash',
                  initialBalanceCents: 50000,
                  currency: 'USD',
                  icon: 'wallet',
                  isArchived: false,
                ),
              ]),
            ),
            categoriesListFilterProvider.overrideWith(
              (ref) => Stream.value([
                const Category(
                  id: 10,
                  name: 'Groceries',
                  type: 'expense',
                  icon: 'shopping_cart',
                  colorValue: 0xFF10B981,
                  parentId: null,
                  isDefault: true,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Open filter bar
      expect(find.byTooltip('Filter Analytics'), findsOneWidget);
      await tester.tap(find.byTooltip('Filter Analytics'));
      await tester.pumpAndSettle();

      // Verify Flow Type pills (Expense, Transfer, Income, All Flow)
      expect(find.text('All Flow'), findsOneWidget);
      expect(find.text('Expense'), findsWidgets);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Income'), findsWidgets);

      // Verify Account multi-select
      expect(find.text('ACCOUNTS'), findsOneWidget);
      expect(find.text('All Accounts'), findsOneWidget);
      expect(find.text('Checking Account'), findsOneWidget);
      expect(find.text('Cash Wallet'), findsOneWidget);

      // Verify Category multi-select
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.text('All Categories'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);

      // Verify Custom Date Range button
      expect(find.text('CUSTOM DATE RANGE'), findsOneWidget);
      expect(find.text('Select Dates'), findsOneWidget);
    });

    testWidgets('ReportsScreen AppBar filter and share buttons are clean IconButtons matching Activity Log', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fullAnalyticsProvider.overrideWith(
              (ref) => Stream.value(
                FullAnalyticsReport(
                  dateRange: DateRange(
                    start: DateTime(2026, 9, 1),
                    end: DateTime(2026, 9, 30),
                    label: 'This Month',
                  ),
                  totalIncomeCents: 0,
                  totalExpenseCents: 0,
                  totalTransferCents: 0,
                  netSavingsCents: 0,
                  overallSavingsRate: 0.0,
                  monthlyTrends: [],
                  categoryBreakdowns: [],
                  momComparison: MonthOverMonthComparison(
                    currentMonthIncomeCents: 0,
                    currentMonthExpenseCents: 0,
                    lastMonthIncomeCents: 0,
                    lastMonthExpenseCents: 0,
                  ),
                  tagBreakdowns: [],
                  accountBreakdowns: [],
                  topMerchants: [],
                  dayOfWeekSpends: [],
                  timeOfMonthSpends: [],
                ),
              ),
            ),
            accountsListProvider.overrideWith((ref) => Stream.value([])),
            categoriesListFilterProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: ReportsScreen(),
          ),
        ),
      );
      await tester.pump();

      // Find Filter Analytics and Share Report
      expect(find.byTooltip('Filter Analytics'), findsOneWidget);
      expect(find.byTooltip('Share Report'), findsOneWidget);

      // Verify they contain direct Icon widgets
      expect(find.descendant(of: find.byTooltip('Filter Analytics'), matching: find.byType(Icon)), findsOneWidget);
      expect(find.descendant(of: find.byTooltip('Share Report'), matching: find.byType(Icon)), findsOneWidget);

      // Verify no decorated Container exists inside the buttons
      expect(find.descendant(of: find.byTooltip('Filter Analytics'), matching: find.byType(Container)), findsNothing);
      expect(find.descendant(of: find.byTooltip('Share Report'), matching: find.byType(Container)), findsNothing);
    });

    testWidgets('TransactionDetailDialog displays transaction details cleanly without image attachment option', (tester) async {
      final item = TransactionWithDetails(
        transaction: TransactionItem(
          id: 1,
          accountId: 1,
          categoryId: 10,
          amountCents: 4500,
          type: 'expense',
          note: 'Coffee Shop',
          date: DateTime(2026, 9, 15, 10, 30),
          tagIds: 'coffee,work',
          receiptPath: '/invalid/path/to/receipt.png',
          isRecurring: false,
          recurringId: null,
          toAccountId: null,
          createdAt: DateTime.now(),
          deletedAt: null,
          feeCents: 0,
        ),
        category: const Category(
          id: 10,
          name: 'Food & Dining',
          type: 'expense',
          icon: 'restaurant',
          colorValue: 0xFFEF4444,
          parentId: null,
          isDefault: true,
        ),
        account: const Account(
          id: 1,
          name: 'Checking Account',
          type: 'bank',
          initialBalanceCents: 100000,
          currency: 'USD',
          icon: 'account_balance',
          isArchived: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => TransactionDetailDialog(item: item),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Transaction details dialog is displayed successfully!
      expect(find.text('Coffee Shop'), findsOneWidget);
      expect(find.text('\$45.00'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Checking Account'), findsOneWidget);
      expect(find.text('Attached Receipt:'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('TransactionsScreen renders Activity header, quick filter pills, date groups, and REPEATS badge', (tester) async {
      final now = DateTime.now();
      final item1 = TransactionWithDetails(
        transaction: TransactionItem(
          id: 1,
          accountId: 1,
          categoryId: 10,
          amountCents: 3500,
          type: 'expense',
          note: 'Blue Bottle Coffee',
          date: now,
          tagIds: '',
          receiptPath: null,
          isRecurring: false,
          recurringId: null,
          toAccountId: null,
          createdAt: now,
          deletedAt: null,
          feeCents: 0,
        ),
        category: const Category(
          id: 10,
          name: 'Dining',
          type: 'expense',
          icon: 'coffee',
          colorValue: 0xFFEF4444,
          parentId: null,
          isDefault: true,
        ),
        account: const Account(
          id: 1,
          name: 'Amex···3009',
          type: 'bank',
          initialBalanceCents: 100000,
          currency: 'USD',
          icon: 'credit_card',
          isArchived: false,
        ),
      );

      final item2 = TransactionWithDetails(
        transaction: TransactionItem(
          id: 2,
          accountId: 1,
          categoryId: 11,
          amountCents: 1500,
          type: 'expense',
          note: 'Figma',
          date: now,
          tagIds: '',
          receiptPath: null,
          isRecurring: true,
          recurringId: 1,
          toAccountId: null,
          createdAt: now,
          deletedAt: null,
          feeCents: 0,
        ),
        category: const Category(
          id: 11,
          name: 'Subscriptions',
          type: 'expense',
          icon: 'refresh_cw',
          colorValue: 0xFF3B82F6,
          parentId: null,
          isDefault: true,
        ),
        account: const Account(
          id: 1,
          name: 'Amex···3009',
          type: 'bank',
          initialBalanceCents: 100000,
          currency: 'USD',
          icon: 'credit_card',
          isArchived: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            filteredTransactionsProvider.overrideWith((ref) => Stream.value([item1, item2])),
            accountsListProvider.overrideWith((ref) => Stream.value([])),
            categoriesListFilterProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: TransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Activity title and records count badge
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('2 records'), findsAtLeast(1));

      // Search bar hint
      expect(find.text('Search merchants, notes, amounts'), findsOneWidget);

      // Quick filter pills
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Recurring'), findsOneWidget);

      // Date group header
      expect(find.text('TODAY'), findsOneWidget);

      // Transactions
      expect(find.text('Blue Bottle Coffee'), findsOneWidget);
      expect(find.text('Figma'), findsOneWidget);
      expect(find.text('REPEATS'), findsOneWidget);
    });
  });

  group('Dues and Loans Deduction Tests', () {
    test('LoanWithDetails correctly calculates remaining and progress', () {
      final loan = Loan(
        id: 1,
        personId: 10,
        type: 'lent',
        amountCents: 10000,
        accountId: 1,
        createdAt: DateTime.now(),
        dueDate: null,
        reminderOption: 'none',
        note: 'Lunch loan',
        isSettled: false,
        settledAt: null,
      );
      final person = Person(id: 10, name: 'Alice', phone: '123456');
      final account = Account(
        id: 1,
        name: 'Cash',
        type: 'cash',
        initialBalanceCents: 50000,
        currency: 'USD',
        icon: 'wallet',
        isArchived: false,
      );

      final loanDetails = LoanWithDetails(
        loan: loan,
        person: person,
        account: account,
        paidAmountCents: 4000,
      );

      expect(loanDetails.remainingCents, 6000);
      expect(loanDetails.progressPercent, 0.4);
      expect(loanDetails.isFullyPaid, isFalse);
      expect(loanDetails.typeLabel, 'Money Given');
    });

    test('LoanSummary aggregates net position and counts correctly', () {
      final summary = LoanSummary(
        totalLentCents: 15000,
        totalBorrowedCents: 5000,
        activeLentCount: 2,
        activeBorrowedCount: 1,
        overdueCount: 0,
      );

      expect(summary.netPositionCents, 10000);
      expect(summary.totalActiveCount, 3);
      expect(summary.hasActiveLoans, isTrue);
    });

    test('Borrowed loan correctly calculates remaining debt and auto-settle threshold', () {
      final borrowedLoan = Loan(
        id: 2,
        personId: 11,
        type: 'borrowed',
        amountCents: 10000,
        accountId: 1,
        createdAt: DateTime.now(),
        dueDate: null,
        reminderOption: 'none',
        note: 'Borrowed for rent',
        isSettled: false,
        settledAt: null,
      );
      final person = Person(id: 11, name: 'Bob', phone: '654321');
      final account = Account(
        id: 1,
        name: 'bKash',
        type: 'wallet',
        initialBalanceCents: 20000,
        currency: 'USD',
        icon: 'wallet',
        isArchived: false,
      );

      // Partial repayment by paying Bob's $40 bill
      final partialDetails = LoanWithDetails(
        loan: borrowedLoan,
        person: person,
        account: account,
        paidAmountCents: 4000,
      );
      expect(partialDetails.remainingCents, 6000);
      expect(partialDetails.progressPercent, 0.4);
      expect(partialDetails.isFullyPaid, isFalse);
      expect(partialDetails.typeLabel, 'Money Received');

      // Full repayment by paying remaining $60
      final fullDetails = LoanWithDetails(
        loan: borrowedLoan,
        person: person,
        account: account,
        paidAmountCents: 10000,
      );
      expect(fullDetails.remainingCents, 0);
      expect(fullDetails.progressPercent, 1.0);
      expect(fullDetails.isFullyPaid, isTrue);
    });
  });

  group('Transfer Charge / Fee Tests', () {
    test('TransactionItem model stores feeCents and calculates total source deduction correctly', () {
      final now = DateTime.now();
      final tx = TransactionItem(
        id: 1,
        accountId: 1,
        categoryId: null,
        amountCents: 10000, // $100
        type: 'transfer',
        note: 'Bank to bKash transfer',
        date: now,
        tagIds: '',
        receiptPath: null,
        isRecurring: false,
        recurringId: null,
        toAccountId: 2,
        createdAt: now,
        deletedAt: null,
        feeCents: 500, // $5 fee
      );

      expect(tx.feeCents, 500);
      expect(tx.amountCents, 10000);
      expect(tx.amountCents + tx.feeCents, 10500);
      expect(CurrencyFormatter.formatCents(tx.feeCents, symbol: '\$'), '\$5.00');
      expect(CurrencyFormatter.formatCents(tx.amountCents + tx.feeCents, symbol: '\$'), '\$105.00');
    });

    testWidgets('TransactionDetailDialog renders transfer fee and total deducted breakdown when fee > 0', (tester) async {
      final now = DateTime.now();
      final item = TransactionWithDetails(
        transaction: TransactionItem(
          id: 1,
          accountId: 1,
          categoryId: null,
          amountCents: 10000,
          type: 'transfer',
          note: 'ATM Withdrawal / Transfer',
          date: now,
          tagIds: '',
          receiptPath: null,
          isRecurring: false,
          recurringId: null,
          toAccountId: 2,
          createdAt: now,
          deletedAt: null,
          feeCents: 250, // $2.50 fee
        ),
        account: const Account(
          id: 1,
          name: 'Main Bank',
          type: 'bank',
          initialBalanceCents: 50000,
          currency: 'USD',
          icon: 'account_balance',
          isArchived: false,
        ),
        toAccount: const Account(
          id: 2,
          name: 'Wallet Cash',
          type: 'cash',
          initialBalanceCents: 1000,
          currency: 'USD',
          icon: 'wallet',
          isArchived: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => TransactionDetailDialog(item: item),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify transfer amount, fee, and breakdown
      expect(find.text('\$100.00'), findsNWidgets(2)); // Big amount + Credited amount
      expect(find.text('Transfer Charge:'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
      expect(find.text('Total Deducted (Main Bank):'), findsOneWidget);
      expect(find.text('\$102.50'), findsOneWidget);
      expect(find.text('Credited (Wallet Cash):'), findsOneWidget);
    });
  });
}



