import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/currency_formatter.dart';

class LoanCard extends StatelessWidget {
  final LoanWithDetails loanWithDetails;
  final VoidCallback? onTap;

  const LoanCard({
    super.key,
    required this.loanWithDetails,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loan = loanWithDetails.loan;
    final person = loanWithDetails.person;
    final isLent = loan.type == 'lent';
    final typeColor = isLent ? AppColors.expense : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: person + type badge
              Row(
                children: [
                  // Person avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                loanWithDetails.typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            if (loanWithDetails.isOverdue) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Overdue',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                            if (loan.isSettled) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Settled',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.formatCompact(loan.amountCents),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (loanWithDetails.paidAmountCents > 0 && !loan.isSettled)
                        Text(
                          '${CurrencyFormatter.formatCompact(loanWithDetails.remainingCents)} left',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Progress bar (if there are payments)
              if (loanWithDetails.paidAmountCents > 0 && !loan.isSettled) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: loanWithDetails.progressPercent,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                    minHeight: 5,
                  ),
                ),
              ],

              // Due date row
              if (loan.dueDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 13,
                      color: loanWithDetails.isOverdue ? Colors.red : Colors.grey[500],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Due ${DateFormat('MMM d, yyyy').format(loan.dueDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: loanWithDetails.isOverdue ? Colors.red : Colors.grey[500],
                        fontWeight: loanWithDetails.isOverdue ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

