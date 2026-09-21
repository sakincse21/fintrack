import 'package:fintrack/core/database/database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoanWithDetails Tests', () {
    test('Calculates remaining amount, progress, and type labels accurately', () {
      final now = DateTime.now();
      final loan = Loan(
        id: 1,
        personId: 10,
        type: 'lent',
        amountCents: 10000, // $100.00
        accountId: 1,
        createdAt: now,
        dueDate: now.add(const Duration(days: 7)),
        reminderOption: '1_week',
        isSettled: false,
      );

      const person = Person(id: 10, name: 'John Doe', phone: '+123456789');
      const account = Account(
        id: 1,
        name: 'Checking',
        type: 'bank',
        initialBalanceCents: 50000,
        currency: 'USD',
        icon: 'account_balance',
        isArchived: false,
      );

      // Scenario 1: No payments yet
      var details = LoanWithDetails(
        loan: loan,
        person: person,
        account: account,
        paidAmountCents: 0,
      );

      expect(details.progressPercent, 0.0);
      expect(details.remainingCents, 10000);
      expect(details.isFullyPaid, false);
      expect(details.isOverdue, false);
      expect(details.typeLabel, 'Money Given');

      // Scenario 2: Partial payment of $40 (4000 cents)
      details = LoanWithDetails(
        loan: loan,
        person: person,
        account: account,
        paidAmountCents: 4000,
      );

      expect(details.progressPercent, 0.4);
      expect(details.remainingCents, 6000);
      expect(details.isFullyPaid, false);

      // Scenario 3: Full payment of $100
      details = LoanWithDetails(
        loan: loan,
        person: person,
        account: account,
        paidAmountCents: 10000,
      );

      expect(details.progressPercent, 1.0);
      expect(details.remainingCents, 0);
      expect(details.isFullyPaid, true);

      // Scenario 4: Overdue loan
      final overdueLoan = Loan(
        id: 2,
        personId: 10,
        type: 'borrowed',
        amountCents: 5000,
        accountId: 1,
        createdAt: now.subtract(const Duration(days: 30)),
        dueDate: now.subtract(const Duration(days: 5)),
        reminderOption: '1_day',
        isSettled: false,
      );

      final overdueDetails = LoanWithDetails(
        loan: overdueLoan,
        person: person,
        account: account,
        paidAmountCents: 1000,
      );

      expect(overdueDetails.isOverdue, true);
      expect(overdueDetails.typeLabel, 'Money Received');
      expect(overdueDetails.remainingCents, 4000);
    });

    test('LoanSummary computes aggregated metrics properly', () {
      final summary = LoanSummary(
        totalLentCents: 15000,
        totalBorrowedCents: 5000,
        activeLentCount: 3,
        activeBorrowedCount: 1,
        overdueCount: 1,
      );

      expect(summary.netPositionCents, 10000); // 15000 - 5000
      expect(summary.totalActiveCount, 4); // 3 + 1
      expect(summary.hasActiveLoans, true);
      expect(summary.overdueCount, 1);
    });
  });
}

