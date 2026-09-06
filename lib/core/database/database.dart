import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../constants/default_categories.dart';

part 'database.g.dart';

// --- Tables ---

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // cash, bank, card, wallet, mobile_banking
  IntColumn get initialBalanceCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get icon => text().withDefault(const Constant('account_balance'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // income, expense
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFF10B981))();
  IntColumn get parentId => integer().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

@DataClassName('TransactionItem')
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get amountCents => integer()();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get date => dateTime()();
  TextColumn get tagIds => text().withDefault(const Constant(''))();
  TextColumn get receiptPath => text().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  IntColumn get recurringId => integer().nullable()();
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get amountCents => integer()();
  TextColumn get type => text()(); // income, expense
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get frequency => text()(); // daily, weekly, monthly, yearly
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get nextRunDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get amountCents => integer()();
  TextColumn get period => text().withDefault(const Constant('monthly'))(); // weekly, monthly, yearly
  DateTimeColumn get startDate => dateTime()();
  BoolColumn get rolloverEnabled => boolean().withDefault(const Constant(false))();
}

@DataClassName('Goal')
class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get targetAmountCents => integer()();
  IntColumn get currentAmountCents => integer().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime()();
  IntColumn get linkedAccountId => integer().nullable().references(Accounts, #id)();
}

@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

@DataClassName('MerchantRule')
class MerchantRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get keyword => text().unique()();
  IntColumn get categoryId => integer().references(Categories, #id)();
}

// Joined transaction model for easy UI consumption
class TransactionWithDetails {
  final TransactionItem transaction;
  final Account account;
  final Category? category;
  final Account? toAccount;

  TransactionWithDetails({
    required this.transaction,
    required this.account,
    this.category,
    this.toAccount,
  });
}

// Joined Budget model
class BudgetWithCategory {
  final Budget budget;
  final Category category;
  final int spentCents;

  BudgetWithCategory({
    required this.budget,
    required this.category,
    required this.spentCents,
  });

  double get progress =>
      budget.amountCents > 0 ? (spentCents / budget.amountCents).clamp(0.0, 2.0) : 0.0;

  int get remainingCents => budget.amountCents - spentCents;
  bool get isExceeded => spentCents > budget.amountCents;
  bool get isWarning => spentCents >= (budget.amountCents * 0.8) && !isExceeded;
}

// Category with pre-aggregated transaction count
class CategoryWithCount {
  final Category category;
  final int transactionCount;

  CategoryWithCount({
    required this.category,
    required this.transactionCount,
  });
}

@DriftDatabase(tables: [
  Accounts,
  Categories,
  Transactions,
  RecurringRules,
  Budgets,
  Goals,
  Tags,
  MerchantRules,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'fintrack_db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaultData();
        },
        beforeOpen: (details) async {
          // Create high-performance indices for sub-millisecond filtering and reports
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date, deleted_at);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id, deleted_at);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_to_account ON transactions(to_account_id, deleted_at);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id, deleted_at);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type, deleted_at);');
          await customStatement('PRAGMA foreign_keys = ON;');
        },
      );

  /// Seeds default accounts, categories, and initial merchant rules
  Future<void> seedDefaultData() async {
    // 1. Seed Accounts
    for (final acc in DefaultCategories.defaultAccounts) {
      await into(accounts).insert(
        AccountsCompanion.insert(
          name: acc['name'] as String,
          type: acc['type'] as String,
          initialBalanceCents: Value(acc['initial_balance_cents'] as int),
          currency: Value(acc['currency'] as String),
          icon: Value(acc['icon'] as String),
        ),
      );
    }

    // 2. Seed Categories & track created IDs
    final categoryIdMap = <String, int>{};

    for (final cat in DefaultCategories.expenseCategories) {
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: cat.name,
          type: cat.type,
          icon: Value(cat.icon),
          colorValue: Value(cat.colorValue),
          isDefault: Value(cat.isDefault),
        ),
      );
      categoryIdMap[cat.name] = id;
    }

    for (final cat in DefaultCategories.incomeCategories) {
      final id = await into(categories).insert(
        CategoriesCompanion.insert(
          name: cat.name,
          type: cat.type,
          icon: Value(cat.icon),
          colorValue: Value(cat.colorValue),
          isDefault: Value(cat.isDefault),
        ),
      );
      categoryIdMap[cat.name] = id;
    }

    // 3. Seed Default Merchant Keyword Rules
    for (final entry in DefaultCategories.defaultMerchantKeywordMapping.entries) {
      final catId = categoryIdMap[entry.value];
      if (catId != null) {
        await into(merchantRules).insert(
          MerchantRulesCompanion.insert(
            keyword: entry.key.toLowerCase(),
            categoryId: catId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }
  }

  // --- Transactions Queries & Streams ---

  Stream<List<TransactionWithDetails>> watchRecentTransactions({int limit = 20}) {
    final query = select(transactions).join([
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(
        alias(accounts, 'to_acc'),
        alias(accounts, 'to_acc').id.equalsExp(transactions.toAccountId),
      ),
    ])
      ..where(transactions.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(transactions.date), OrderingTerm.desc(transactions.id)])
      ..limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(transactions),
          account: row.readTable(accounts),
          category: row.readTableOrNull(categories),
          toAccount: row.readTableOrNull(alias(accounts, 'to_acc')),
        );
      }).toList();
    });
  }

  Stream<List<TransactionWithDetails>> watchTransactionsFiltered({
    DateTime? startDate,
    DateTime? endDate,
    int? accountId,
    int? categoryId,
    Iterable<int>? categoryIds,
    String? type,
    Iterable<String>? types,
    String? searchQuery,
    String? tag,
  }) {
    final query = select(transactions).join([
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(
        alias(accounts, 'to_acc'),
        alias(accounts, 'to_acc').id.equalsExp(transactions.toAccountId),
      ),
    ])..where(transactions.deletedAt.isNull());

    if (startDate != null) {
      query.where(transactions.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where(transactions.date.isSmallerOrEqualValue(endDate));
    }
    if (accountId != null) {
      query.where(transactions.accountId.equals(accountId) | transactions.toAccountId.equals(accountId));
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      query.where(transactions.categoryId.isIn(categoryIds));
    } else if (categoryId != null) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (types != null && types.isNotEmpty) {
      query.where(transactions.type.isIn(types));
    } else if (type != null && type.isNotEmpty && type != 'all') {
      query.where(transactions.type.equals(type));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(transactions.note.lower().like(term));
    }
    if (tag != null && tag.trim().isNotEmpty) {
      query.where(transactions.tagIds.like('%$tag%'));
    }

    query.orderBy([OrderingTerm.desc(transactions.date), OrderingTerm.desc(transactions.id)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(transactions),
          account: row.readTable(accounts),
          category: row.readTableOrNull(categories),
          toAccount: row.readTableOrNull(alias(accounts, 'to_acc')),
        );
      }).toList();
    });
  }

  Future<List<TransactionWithDetails>> getTransactionsForDateRange(
    DateTime start,
    DateTime end, {
    int? accountId,
    Set<int>? categoryIds,
    String? type,
  }) {
    final query = select(transactions).join([
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(
        alias(accounts, 'to_acc'),
        alias(accounts, 'to_acc').id.equalsExp(transactions.toAccountId),
      ),
    ])
      ..where(transactions.deletedAt.isNull())
      ..where(transactions.date.isBiggerOrEqualValue(start))
      ..where(transactions.date.isSmallerOrEqualValue(end));

    if (accountId != null) {
      query.where(transactions.accountId.equals(accountId) | transactions.toAccountId.equals(accountId));
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      query.where(transactions.categoryId.isIn(categoryIds));
    }

    if (type != null && type != 'all') {
      query.where(transactions.type.equals(type));
    }

    query.orderBy([OrderingTerm.desc(transactions.date)]);

    return query.get().then((rows) => rows.map((row) {
          return TransactionWithDetails(
            transaction: row.readTable(transactions),
            account: row.readTable(accounts),
            category: row.readTableOrNull(categories),
            toAccount: row.readTableOrNull(alias(accounts, 'to_acc')),
          );
        }).toList());
  }

  // Soft delete transaction (for one-tap undo)
  Future<int> softDeleteTransaction(int id) {
    return (update(transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
  }

  // Restore soft-deleted transaction
  Future<int> restoreTransaction(int id) {
    return (update(transactions)..where((t) => t.id.equals(id)))
        .write(const TransactionsCompanion(deletedAt: Value(null)));
  }

  // Permanent delete
  Future<int> hardDeleteTransaction(int id) {
    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }

  // --- Accounts Queries ---

  Stream<List<Account>> watchAllAccounts({bool includeArchived = false}) {
    final query = select(accounts);
    if (!includeArchived) {
      query.where((a) => a.isArchived.equals(false));
    }
    return query.watch();
  }

  Future<List<Account>> getAllAccounts({bool includeArchived = false}) {
    final query = select(accounts);
    if (!includeArchived) {
      query.where((a) => a.isArchived.equals(false));
    }
    return query.get();
  }

  // Fast SQL-aggregated live balance for a single account
  Future<int> calculateAccountBalance(int accountId) async {
    final acc = await (select(accounts)..where((a) => a.id.equals(accountId))).getSingleOrNull();
    if (acc == null) return 0;

    final row = await customSelect(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' AND account_id = :accId THEN amount_cents ELSE 0 END), 0) AS income_tot,
        COALESCE(SUM(CASE WHEN type = 'expense' AND account_id = :accId THEN amount_cents ELSE 0 END), 0) AS expense_tot,
        COALESCE(SUM(CASE WHEN type = 'transfer' AND account_id = :accId THEN amount_cents ELSE 0 END), 0) AS transfer_out_tot,
        COALESCE(SUM(CASE WHEN type = 'transfer' AND to_account_id = :accId THEN amount_cents ELSE 0 END), 0) AS transfer_in_tot
      FROM transactions
      WHERE deleted_at IS NULL AND (account_id = :accId OR to_account_id = :accId)
      ''',
      variables: [Variable.withInt(accountId)],
      readsFrom: {transactions},
    ).getSingle();

    final inc = row.read<int>('income_tot');
    final exp = row.read<int>('expense_tot');
    final tfOut = row.read<int>('transfer_out_tot');
    final tfIn = row.read<int>('transfer_in_tot');

    return acc.initialBalanceCents + inc - exp - tfOut + tfIn;
  }

  // Fast single-pass SQL-aggregated live balances for ALL accounts
  Future<Map<int, int>> calculateAllAccountBalances() async {
    final accList = await (select(accounts)..where((a) => a.isArchived.equals(false))).get();
    final balances = <int, int>{for (var a in accList) a.id: a.initialBalanceCents};

    final rows = await customSelect(
      '''
      SELECT
        account_id,
        to_account_id,
        type,
        SUM(amount_cents) AS total_cents
      FROM transactions
      WHERE deleted_at IS NULL
      GROUP BY account_id, to_account_id, type
      ''',
      readsFrom: {transactions},
    ).get();

    for (final row in rows) {
      final accId = row.read<int>('account_id');
      final toAccId = row.readNullable<int>('to_account_id');
      final type = row.read<String>('type');
      final total = row.read<int>('total_cents');

      if (type == 'income') {
        if (balances.containsKey(accId)) {
          balances[accId] = balances[accId]! + total;
        }
      } else if (type == 'expense') {
        if (balances.containsKey(accId)) {
          balances[accId] = balances[accId]! - total;
        }
      } else if (type == 'transfer') {
        if (balances.containsKey(accId)) {
          balances[accId] = balances[accId]! - total;
        }
        if (toAccId != null && balances.containsKey(toAccId)) {
          balances[toAccId] = balances[toAccId]! + total;
        }
      }
    }

    return balances;
  }

  // --- Categories Queries ---

  Stream<List<CategoryWithCount>> watchCategoriesWithCounts({String? type}) {
    final txCount = transactions.id.count();
    final query = select(categories).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(categories.id) &
            transactions.deletedAt.isNull(),
        useColumns: false,
      ),
    ]);

    if (type != null && type.isNotEmpty) {
      query.where(categories.type.equals(type));
    }

    query
      ..groupBy([categories.id])
      ..orderBy([
        OrderingTerm.desc(txCount),
        OrderingTerm.asc(categories.name),
      ]);

    return query.watch().map((rows) => rows.map((r) => CategoryWithCount(
          category: r.readTable(categories),
          transactionCount: r.read(txCount) ?? 0,
        )).toList());
  }

  Stream<List<Category>> watchCategories({String? type}) {
    final txCount = transactions.id.count();
    final query = select(categories).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(categories.id) &
            transactions.deletedAt.isNull(),
        useColumns: false,
      ),
    ]);

    if (type != null && type.isNotEmpty) {
      query.where(categories.type.equals(type));
    }

    query
      ..groupBy([categories.id])
      ..orderBy([
        OrderingTerm.desc(txCount),
        OrderingTerm.asc(categories.name),
      ]);

    return query.watch().map((rows) => rows.map((r) => r.readTable(categories)).toList());
  }

  Future<List<Category>> getCategories({String? type}) {
    final txCount = transactions.id.count();
    final query = select(categories).join([
      leftOuterJoin(
        transactions,
        transactions.categoryId.equalsExp(categories.id) &
            transactions.deletedAt.isNull(),
        useColumns: false,
      ),
    ]);

    if (type != null && type.isNotEmpty) {
      query.where(categories.type.equals(type));
    }

    query
      ..groupBy([categories.id])
      ..orderBy([
        OrderingTerm.desc(txCount),
        OrderingTerm.asc(categories.name),
      ]);

    return query.get().then((rows) => rows.map((r) => r.readTable(categories)).toList());
  }

  Future<int> getCategoryTransactionCount(int categoryId) async {
    final count = transactions.id.count();
    final query = selectOnly(transactions)
      ..addColumns([count])
      ..where(transactions.categoryId.equals(categoryId) & transactions.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<int> reassignCategoryTransactions(int oldCategoryId, int newCategoryId) async {
    return (update(transactions)..where((t) => t.categoryId.equals(oldCategoryId)))
        .write(TransactionsCompanion(categoryId: Value(newCategoryId)));
  }

  Future<int> deleteCategory(int categoryId) async {
    await (delete(budgets)..where((b) => b.categoryId.equals(categoryId))).go();
    await (delete(merchantRules)..where((m) => m.categoryId.equals(categoryId))).go();
    return (delete(categories)..where((c) => c.id.equals(categoryId))).go();
  }

  // --- Merchant Rules & Auto-categorization ---

  Stream<List<MerchantRule>> watchMerchantRules() => select(merchantRules).watch();

  Future<Category?> findCategoryByMerchant(String note) async {
    if (note.trim().isEmpty) return null;
    final lower = note.trim().toLowerCase();

    final rules = await select(merchantRules).get();
    // Sort rules by keyword length descending (most specific match first)
    rules.sort((a, b) => b.keyword.length.compareTo(a.keyword.length));

    for (final rule in rules) {
      if (lower.contains(rule.keyword.toLowerCase())) {
        return (select(categories)..where((c) => c.id.equals(rule.categoryId)))
            .getSingleOrNull();
      }
    }
    return null;
  }

  Future<void> saveMerchantRule(String keyword, int categoryId) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    if (cleanKeyword.isEmpty || cleanKeyword.length < 2) return;

    await into(merchantRules).insertOnConflictUpdate(
      MerchantRulesCompanion.insert(
        keyword: cleanKeyword,
        categoryId: categoryId,
      ),
    );
  }

  // --- Budgets ---

  Stream<List<BudgetWithCategory>> watchBudgetsWithProgress(DateTime monthDate) {
    final start = DateTime(monthDate.year, monthDate.month, 1);
    final end = DateTime(monthDate.year, monthDate.month + 1, 0, 23, 59, 59);

    final query = select(budgets).join([
      innerJoin(categories, categories.id.equalsExp(budgets.categoryId)),
    ]);

    return query.watch().asyncMap((rows) async {
      final List<BudgetWithCategory> result = [];

      for (final row in rows) {
        final budget = row.readTable(budgets);
        final category = row.readTable(categories);

        // Sum expenses for this category in the month
        final txList = await (select(transactions)
              ..where((t) =>
                  t.categoryId.equals(category.id) &
                  t.type.equals('expense') &
                  t.deletedAt.isNull() &
                  t.date.isBiggerOrEqualValue(start) &
                  t.date.isSmallerOrEqualValue(end)))
            .get();

        final spent = txList.fold<int>(0, (sum, tx) => sum + tx.amountCents);

        result.add(BudgetWithCategory(
          budget: budget,
          category: category,
          spentCents: spent,
        ));
      }

      return result;
    });
  }

  // --- Goals ---

  Stream<List<Goal>> watchAllGoals() => select(goals).watch();

  // --- Recurring Rules ---

  Stream<List<RecurringRule>> watchActiveRecurringRules() =>
      (select(recurringRules)..where((r) => r.isActive.equals(true))).watch();

  Future<List<RecurringRule>> getDueRecurringRules(DateTime now) {
    return (select(recurringRules)
          ..where((r) => r.isActive.equals(true) & r.nextRunDate.isSmallerOrEqualValue(now)))
        .get();
  }

  // --- Tags ---

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<int> getOrCreateTag(String name) async {
    final clean = name.trim().toLowerCase();
    final existing = await (select(tags)..where((t) => t.name.equals(clean))).getSingleOrNull();
    if (existing != null) return existing.id;
    return into(tags).insert(TagsCompanion.insert(name: clean));
  }
}

