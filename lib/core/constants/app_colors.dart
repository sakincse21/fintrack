import 'package:flutter/material.dart';

class AppColors {
  // VittaFinance Primary Brand Palette (Warm Terracotta Coral)
  static const Color primary = Color(0xFFFF5B35); // VittaFinance Radiant Coral
  static const Color primaryDark = Color(0xFFE04822);
  static const Color primaryLight = Color(0xFFFF7E5F);
  static const Color primaryTint = Color(0xFFFFEFEA);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF623A), Color(0xFFF04D23)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color secondary = Color(0xFF2EB872); // VittaFinance Mint Green
  static const Color secondaryDark = Color(0xFF23965B);
  static const Color secondaryLight = Color(0xFF38D685);

  // Financial Semantics
  static const Color income = Color(0xFF2EB872); // Mint Green
  static const Color incomeDark = Color(0xFF23965B);
  static const Color incomeLight = Color(0xFF38D685);
  static const Color incomeTint = Color(0xFFE8F8F0);

  static const Color expense = Color(0xFFFF5B35); // Terracotta Coral
  static const Color expenseDark = Color(0xFFE04822);
  static const Color expenseLight = Color(0xFFFF7E5F);
  static const Color expenseTint = Color(0xFFFFEFEA);
  static const Color expenseMuted = Color(0xFFD94D28);

  static const Color transfer = Color(0xFF3B82F6); // Cobalt Blue
  static const Color transferDark = Color(0xFF2563EB);
  static const Color transferLight = Color(0xFF60A5FA);
  static const Color transferTint = Color(0xFFEFF6FF);

  // Budget & Warning States
  static const Color budgetNormal = income;
  static const Color budgetWarning = warning;
  static const Color budgetExceeded = expense;

  static const Color warning = Color(0xFFF59E0B); // Warm Amber
  static const Color warningTint = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoTint = Color(0xFFDBEAFE);

  // Dark Theme Colors (VittaFinance Warm Espresso Slate)
  static const Color darkBackground = Color(0xFF141211); // Warm Dark Slate
  static const Color darkSurface = Color(0xFF1D1A18); // Espresso Surface
  static const Color darkSurfaceElevated = Color(0xFF272421); // Elevated Card
  static const Color darkBorder = Color(0xFF36302B); // Subtle Warm Outline
  static const Color darkBorderSubtle = Color(0xFF24201D);
  static const Color darkTextPrimary = Color(0xFFFAF7F2);
  static const Color darkTextSecondary = Color(0xFFA69F97);
  static const Color darkTextMuted = Color(0xFF6E6760);

  // Light Theme Colors (VittaFinance Warm Sand & Pure White)
  static const Color lightBackground = Color(0xFFFDF8F2); // Warm Sand Canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // Crisp Pure White
  static const Color lightSurfaceElevated = Color(0xFFF6EFE6); // Sand Gray
  static const Color lightBorder = Color(0xFFEDE4D8); // Soft Warm Border
  static const Color lightBorderSubtle = Color(0xFFF5EFE6);
  static const Color lightTextPrimary = Color(0xFF1E1B18); // Warm Charcoal
  static const Color lightTextSecondary = Color(0xFF706B65); // Muted Warm Gray
  static const Color lightTextMuted = Color(0xFF9C958D);

  // VittaFinance Category Color Palette (for donut chart and category avatars)
  static const List<Color> categoryPalette = [
    Color(0xFFFF5B35), // Terracotta Coral
    Color(0xFFF59E0B), // Warm Amber
    Color(0xFF2EB872), // Mint Green
    Color(0xFF3B82F6), // Cobalt Blue
    Color(0xFF885038), // Terracotta Brown
    Color(0xFFFB923C), // Peach
    Color(0xFF8B5CF6), // Soft Violet
    Color(0xFFEC4899), // Rose Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF10B981), // Emerald
    Color(0xFFA855F7), // Purple
    Color(0xFF84CC16), // Lime
  ];
}
