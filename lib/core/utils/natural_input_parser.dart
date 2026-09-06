import '../constants/default_categories.dart';

class ParsedTransactionInput {
  final int? amountCents;
  final String note;
  final String? suggestedCategoryName;
  final String type; // 'expense' or 'income'

  ParsedTransactionInput({
    this.amountCents,
    required this.note,
    this.suggestedCategoryName,
    this.type = 'expense',
  });
}

class NaturalInputParser {
  /// Parse natural language text into a structured amount, note, and suggested category
  /// Examples:
  /// - "200 for lunch" -> amount: 20000 cents, note: "lunch", category: "Food & Dining"
  /// - "₹450 grocery at walmart" -> amount: 45000 cents, note: "grocery at walmart", category: "Groceries"
  /// - "Uber 35.50" -> amount: 3550 cents, note: "Uber", category: "Transportation"
  /// - "Salary 5000" -> amount: 500000 cents, note: "Salary", category: "Salary", type: "income"
  static ParsedTransactionInput parse(String rawText, {Map<String, String>? customKeywordMap}) {
    final text = rawText.trim();
    if (text.isEmpty) {
      return ParsedTransactionInput(note: '');
    }

    // Combine custom keywords with default keyword mapping
    final keywordMap = <String, String>{
      ...DefaultCategories.defaultMerchantKeywordMapping,
      if (customKeywordMap != null) ...customKeywordMap,
    };

    // Regex to extract numeric amount (supports prefixes like $, ₹, ৳, €, £, etc.)
    // Examples matched: "200", "200.50", "₹500", "$12.99", "1,250"
    final amountRegex = RegExp(r'(?:[\$₹৳€£¥]|\b)?(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)\b');
    final match = amountRegex.firstMatch(text);

    int? extractedCents;
    String cleanNote = text;

    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      if (amountStr != null) {
        final parsedDouble = double.tryParse(amountStr);
        if (parsedDouble != null) {
          extractedCents = (parsedDouble * 100).round();
          // Remove the amount from the text to leave the clean note
          cleanNote = text.replaceFirst(match.group(0)!, '').trim();
          // Clean up common filler words like "for", "at", "on", "in", "spent", "paid"
          cleanNote = cleanNote
              .replaceAll(RegExp(r'^(?:for|at|on|in|spent|paid|buy|bought)\s+', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s+(?:for|at|on|in)$', caseSensitive: false), '')
              .trim();
        }
      }
    }

    if (cleanNote.isEmpty && extractedCents != null) {
      cleanNote = 'Expense';
    }

    // Check for category matching based on keywords in note or raw text
    final lowerNote = (cleanNote.isNotEmpty ? cleanNote : text).toLowerCase();
    String? matchedCategory;

    // Search keywords (longest matching keyword first for precision)
    final sortedKeywords = keywordMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final kw in sortedKeywords) {
      if (lowerNote.contains(kw.toLowerCase())) {
        matchedCategory = keywordMap[kw];
        break;
      }
    }

    // Determine type: check if matched category is income
    String txType = 'expense';
    if (matchedCategory != null) {
      final isIncome = DefaultCategories.incomeCategories
          .any((c) => c.name.toLowerCase() == matchedCategory!.toLowerCase());
      if (isIncome) txType = 'income';
    }

    return ParsedTransactionInput(
      amountCents: extractedCents,
      note: cleanNote.isNotEmpty ? cleanNote : text,
      suggestedCategoryName: matchedCategory,
      type: txType,
    );
  }
}

