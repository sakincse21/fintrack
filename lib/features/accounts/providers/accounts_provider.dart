import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';

final accountsListProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllAccounts();
});

class AccountWithBalance {
  final Account account;
  final int balanceCents;

  AccountWithBalance({
    required this.account,
    required this.balanceCents,
  });

  bool get isLiability =>
      account.type == 'card' || account.type == 'loan' || balanceCents < 0;
}

class NetWorthSummary {
  final int totalAssetsCents;
  final int totalLiabilitiesCents;
  final int netWorthCents;
  final List<AccountWithBalance> accountsWithBalance;

  NetWorthSummary({
    required this.totalAssetsCents,
    required this.totalLiabilitiesCents,
    required this.netWorthCents,
    required this.accountsWithBalance,
  });
}

final accountsWithBalancesProvider = StreamProvider<List<AccountWithBalance>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllAccounts().asyncMap((accounts) async {
    final balances = await db.calculateAllAccountBalances();
    return accounts.map((acc) {
      return AccountWithBalance(
        account: acc,
        balanceCents: balances[acc.id] ?? acc.initialBalanceCents,
      );
    }).toList();
  });
});

final netWorthProvider = Provider<AsyncValue<NetWorthSummary>>((ref) {
  final accountsAsync = ref.watch(accountsWithBalancesProvider);

  return accountsAsync.whenData((accountsWithBal) {
    int assets = 0;
    int liabilities = 0;

    for (final item in accountsWithBal) {
      if (item.account.type == 'card' || item.account.type == 'loan') {
        if (item.balanceCents < 0) {
          liabilities += item.balanceCents.abs();
        } else {
          assets += item.balanceCents;
        }
      } else {
        if (item.balanceCents >= 0) {
          assets += item.balanceCents;
        } else {
          liabilities += item.balanceCents.abs();
        }
      }
    }

    final netWorth = assets - liabilities;

    return NetWorthSummary(
      totalAssetsCents: assets,
      totalLiabilitiesCents: liabilities,
      netWorthCents: netWorth,
      accountsWithBalance: accountsWithBal,
    );
  });
});

