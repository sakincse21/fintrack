import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dayFormat = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat _shortDayFormat = DateFormat('MMM d');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _shortMonthFormat = DateFormat('MMM yy');
  static final DateFormat _timeFormat = DateFormat('h:mm a');

  static String formatFullDate(DateTime date) => _dayFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDayFormat.format(date);
  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);
  static String formatShortMonth(DateTime date) => _shortMonthFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);

  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    final diff = today.difference(itemDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    if (diff > 1 && diff <= 7) return '$diff days ago';

    return _shortDayFormat.format(date);
  }

  /// Start of the given day
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 0, 0, 0);

  /// End of the given day
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  /// Start of month
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1, 0, 0, 0);

  /// End of month
  static DateTime endOfMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }

  /// Start of year
  static DateTime startOfYear(DateTime date) =>
      DateTime(date.year, 1, 1, 0, 0, 0);

  /// End of year
  static DateTime endOfYear(DateTime date) =>
      DateTime(date.year, 12, 31, 23, 59, 59, 999);
}

enum DateRangeFilter {
  thisMonth,
  lastMonth,
  last30Days,
  last90Days,
  thisYear,
  allTime,
  custom,
}

class DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  DateRange({required this.start, required this.end, required this.label});

  factory DateRange.fromFilter(DateRangeFilter filter, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (filter) {
      case DateRangeFilter.thisMonth:
        return DateRange(
          start: AppDateUtils.startOfMonth(now),
          end: AppDateUtils.endOfMonth(now),
          label: 'This Month',
        );
      case DateRangeFilter.lastMonth:
        final lastMonthDate = DateTime(now.year, now.month - 1, 1);
        return DateRange(
          start: AppDateUtils.startOfMonth(lastMonthDate),
          end: AppDateUtils.endOfMonth(lastMonthDate),
          label: 'Last Month',
        );
      case DateRangeFilter.last30Days:
        return DateRange(
          start: AppDateUtils.startOfDay(now.subtract(const Duration(days: 30))),
          end: AppDateUtils.endOfDay(now),
          label: 'Last 30 Days',
        );
      case DateRangeFilter.last90Days:
        return DateRange(
          start: AppDateUtils.startOfDay(now.subtract(const Duration(days: 90))),
          end: AppDateUtils.endOfDay(now),
          label: 'Last 90 Days',
        );
      case DateRangeFilter.thisYear:
        return DateRange(
          start: AppDateUtils.startOfYear(now),
          end: AppDateUtils.endOfYear(now),
          label: 'This Year',
        );
      case DateRangeFilter.allTime:
        return DateRange(
          start: DateTime(2000, 1, 1),
          end: DateTime(2100, 1, 1),
          label: 'All Time',
        );
      case DateRangeFilter.custom:
        return DateRange(
          start: customStart ?? AppDateUtils.startOfMonth(now),
          end: customEnd ?? AppDateUtils.endOfMonth(now),
          label: 'Custom Range',
        );
    }
  }
}

