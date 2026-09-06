import 'dart:math';
import 'package:drift/drift.dart';
import '../database/database.dart';

class SampleDataSeeder {
  final AppDatabase db;

  SampleDataSeeder(this.db);

  /// Seeds realistic 3-month sample data for comprehensive testing and immediate visual exploration
  Future<void> seedRealisticDemoData() async {
    final accountsList = await db.getAllAccounts();
    final categoriesList = await db.getCategories();

    if (accountsList.isEmpty || categoriesList.isEmpty) return;

    final bankAcc = accountsList.firstWhere(
      (a) => a.type == 'bank',
      orElse: () => accountsList.first,
    );
    final cashAcc = accountsList.firstWhere(
      (a) => a.type == 'cash',
      orElse: () => accountsList.first,
    );
    final mobileAcc = accountsList.firstWhere(
      (a) => a.type == 'mobile_banking' || a.type == 'wallet',
      orElse: () => accountsList.first,
    );
    final cardAcc = accountsList.firstWhere(
      (a) => a.type == 'card',
      orElse: () => accountsList.last,
    );

    // Update initial balances to realistic numbers
    await (db.update(db.accounts)..where((a) => a.id.equals(bankAcc.id)))
        .write(const AccountsCompanion(initialBalanceCents: Value(350000))); // $3,500
    await (db.update(db.accounts)..where((a) => a.id.equals(cashAcc.id)))
        .write(const AccountsCompanion(initialBalanceCents: Value(25000))); // $250
    await (db.update(db.accounts)..where((a) => a.id.equals(mobileAcc.id)))
        .write(const AccountsCompanion(initialBalanceCents: Value(45000))); // $450
    await (db.update(db.accounts)..where((a) => a.id.equals(cardAcc.id)))
        .write(const AccountsCompanion(initialBalanceCents: Value(-12000))); // -$120 (card balance)

    // Map categories by name for easy lookup
    final catMap = <String, Category>{};
    for (final c in categoriesList) {
      catMap[c.name] = c;
    }

    final now = DateTime.now();
    final random = Random(42); // Deterministic seed for reproducible tests

    // 1. Seed Budgets
    final budgetCategories = [
      {'name': 'Food & Dining', 'amount': 35000},
      {'name': 'Groceries', 'amount': 40000},
      {'name': 'Transportation', 'amount': 15000},
      {'name': 'Entertainment', 'amount': 10000},
      {'name': 'Shopping', 'amount': 20000},
      {'name': 'Bills & Utilities', 'amount': 18000},
    ];

    for (final b in budgetCategories) {
      final cat = catMap[b['name']];
      if (cat != null) {
        // Check if budget exists
        final existing = await (db.select(db.budgets)..where((bg) => bg.categoryId.equals(cat.id))).getSingleOrNull();
        if (existing == null) {
          await db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              categoryId: cat.id,
              amountCents: b['amount'] as int,
              period: const Value('monthly'),
              startDate: DateTime(now.year, now.month, 1),
              rolloverEnabled: const Value(true),
            ),
          );
        }
      }
    }

    // 2. Seed Goals
    final existingGoals = await db.watchAllGoals().first;
    if (existingGoals.isEmpty) {
      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          name: 'Emergency Fund',
          targetAmountCents: 500000, // $5,000
          currentAmountCents: const Value(340000), // $3,400
          targetDate: now.add(const Duration(days: 180)),
          linkedAccountId: Value(bankAcc.id),
        ),
      );
      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          name: 'Japan Vacation Trip',
          targetAmountCents: 250000, // $2,500
          currentAmountCents: const Value(115000), // $1,150
          targetDate: now.add(const Duration(days: 240)),
          linkedAccountId: Value(bankAcc.id),
        ),
      );
      await db.into(db.goals).insert(
        GoalsCompanion.insert(
          name: 'New M4 MacBook Pro',
          targetAmountCents: 199900, // $1,999
          currentAmountCents: const Value(150000), // $1,500
          targetDate: now.add(const Duration(days: 45)),
          linkedAccountId: Value(bankAcc.id),
        ),
      );
    }

    // 3. Seed Recurring Rules
    final existingRules = await (db.select(db.recurringRules)).get();
    if (existingRules.isEmpty) {
      final rentCat = catMap['Housing & Rent'];
      if (rentCat != null) {
        await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            accountId: bankAcc.id,
            categoryId: Value(rentCat.id),
            amountCents: 120000, // $1,200
            type: 'expense',
            note: const Value('Apartment Rent'),
            frequency: 'monthly',
            nextRunDate: DateTime(now.year, now.month + 1, 1),
          ),
        );
      }

      final salaryCat = catMap['Salary'];
      if (salaryCat != null) {
        await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            accountId: bankAcc.id,
            categoryId: Value(salaryCat.id),
            amountCents: 420000, // $4,200
            type: 'income',
            note: const Value('Monthly Tech Salary'),
            frequency: 'monthly',
            nextRunDate: DateTime(now.year, now.month + 1, 1),
          ),
        );
      }

      final entCat = catMap['Entertainment'];
      if (entCat != null) {
        await db.into(db.recurringRules).insert(
          RecurringRulesCompanion.insert(
            accountId: cardAcc.id,
            categoryId: Value(entCat.id),
            amountCents: 1599, // $15.99
            type: 'expense',
            note: const Value('Netflix Subscription'),
            frequency: 'monthly',
            nextRunDate: DateTime(now.year, now.month, now.day + 5),
          ),
        );
      }
    }

    // 4. Seed 3 Months of Realistic Transactions
    // Sample transactions dataset template
    final expenseTemplates = [
      {'cat': 'Food & Dining', 'note': 'Starbucks Coffee', 'min': 450, 'max': 950, 'acc': cardAcc, 'tag': '#coffee'},
      {'cat': 'Food & Dining', 'note': 'Lunch at Chipotle', 'min': 1200, 'max': 1850, 'acc': cardAcc, 'tag': '#lunch'},
      {'cat': 'Food & Dining', 'note': 'Dinner at Olive Garden', 'min': 3500, 'max': 6500, 'acc': bankAcc, 'tag': '#dining'},
      {'cat': 'Food & Dining', 'note': 'KFC Burger & Fries', 'min': 850, 'max': 1500, 'acc': cashAcc, 'tag': '#fastfood'},
      {'cat': 'Groceries', 'note': 'Walmart Supercenter Groceries', 'min': 4500, 'max': 12500, 'acc': bankAcc, 'tag': '#groceries'},
      {'cat': 'Groceries', 'note': 'Trader Joe fresh vegetables', 'min': 2800, 'max': 6200, 'acc': bankAcc, 'tag': '#groceries'},
      {'cat': 'Groceries', 'note': 'Local Bakery & Dairy', 'min': 650, 'max': 1400, 'acc': cashAcc, 'tag': '#groceries'},
      {'cat': 'Transportation', 'note': 'Uber Ride to Downtown', 'min': 1400, 'max': 2900, 'acc': cardAcc, 'tag': '#commute'},
      {'cat': 'Transportation', 'note': 'Metro monthly transit card', 'min': 3500, 'max': 5000, 'acc': mobileAcc, 'tag': '#commute'},
      {'cat': 'Transportation', 'note': 'Gas Station Fuel', 'min': 3500, 'max': 5500, 'acc': cardAcc, 'tag': '#fuel'},
      {'cat': 'Bills & Utilities', 'note': 'High-speed Fiber Internet', 'min': 5000, 'max': 6500, 'acc': bankAcc, 'tag': '#bills'},
      {'cat': 'Bills & Utilities', 'note': 'Electricity & Power Bill', 'min': 7500, 'max': 11000, 'acc': bankAcc, 'tag': '#bills'},
      {'cat': 'Entertainment', 'note': 'Movie Tickets AMC', 'min': 2400, 'max': 3800, 'acc': cardAcc, 'tag': '#weekend'},
      {'cat': 'Entertainment', 'note': 'Spotify Premium Family', 'min': 1699, 'max': 1699, 'acc': cardAcc, 'tag': '#subscription'},
      {'cat': 'Shopping', 'note': 'Amazon Order - Home Supplies', 'min': 2500, 'max': 8900, 'acc': cardAcc, 'tag': '#shopping'},
      {'cat': 'Shopping', 'note': 'Zara Autumn Jacket', 'min': 6500, 'max': 11000, 'acc': cardAcc, 'tag': '#clothes'},
      {'cat': 'Health & Medical', 'note': 'Pharmacy Prescription Meds', 'min': 1500, 'max': 4500, 'acc': cashAcc, 'tag': '#health'},
      {'cat': 'Personal Care', 'note': 'Barber Haircut & Grooming', 'min': 2500, 'max': 4000, 'acc': cashAcc, 'tag': '#grooming'},
    ];

    // Clear old sample transactions to prevent duplicate accumulation if re-seeded
    await db.customStatement('DELETE FROM transactions');

    // Generate for 90 days back
    for (int dayOffset = 90; dayOffset >= 0; dayOffset--) {
      final dayDate = now.subtract(Duration(days: dayOffset));

      // 1st of month: Salary + Rent
      if (dayDate.day == 1) {
        final salaryCat = catMap['Salary'];
        if (salaryCat != null) {
          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: bankAcc.id,
              categoryId: Value(salaryCat.id),
              amountCents: 420000, // $4,200
              type: 'income',
              note: const Value('Monthly Tech Salary'),
              date: dayDate.copyWith(hour: 9, minute: 0),
              tagIds: const Value('#salary,#work'),
            ),
          );
        }

        final rentCat = catMap['Housing & Rent'];
        if (rentCat != null) {
          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: bankAcc.id,
              categoryId: Value(rentCat.id),
              amountCents: 120000, // $1,200
              type: 'expense',
              note: const Value('Apartment Rent'),
              date: dayDate.copyWith(hour: 10, minute: 30),
              tagIds: const Value('#rent,#essential'),
            ),
          );
        }
      }

      // Mid-month freelance bonus
      if (dayDate.day == 15 && dayOffset > 10) {
        final freeCat = catMap['Freelance & Projects'];
        if (freeCat != null) {
          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              accountId: mobileAcc.id,
              categoryId: Value(freeCat.id),
              amountCents: 65000 + random.nextInt(40000), // $650 - $1,050
              type: 'income',
              note: const Value('Upwork Client Mobile App UI'),
              date: dayDate.copyWith(hour: 14, minute: 15),
              tagIds: const Value('#freelance,#sidehustle'),
            ),
          );
        }
      }

      // 1 to 3 daily expenses
      final dailyCount = random.nextInt(3) + 1;
      for (int i = 0; i < dailyCount; i++) {
        final template = expenseTemplates[random.nextInt(expenseTemplates.length)];
        final cat = catMap[template['cat'] as String];
        final acc = template['acc'] as Account;
        final minCents = template['min'] as int;
        final maxCents = template['max'] as int;
        final amount = minCents + (maxCents > minCents ? random.nextInt(maxCents - minCents) : 0);

        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            accountId: acc.id,
            categoryId: Value(cat?.id),
            amountCents: amount,
            type: 'expense',
            note: Value(template['note'] as String),
            date: dayDate.copyWith(
              hour: 8 + random.nextInt(13),
              minute: random.nextInt(60),
            ),
            tagIds: Value(template['tag'] as String),
          ),
        );
      }
    }
  }
}

