import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../quick_add/presentation/quick_add_sheet.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.0,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          indicatorColor: AppColors.primary.withValues(alpha: 0.16),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          elevation: 0,
          height: 74,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, size: 24),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary, size: 24),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined, size: 24),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded, size: 24),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 24),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.handshake_outlined, size: 24),
              selectedIcon: Icon(Icons.handshake_rounded, color: AppColors.primary, size: 24),
              label: 'Dues',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_rounded, size: 24),
              selectedIcon: Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
              label: 'Settings',
            ),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => QuickAddSheet.show(context),
            borderRadius: BorderRadius.circular(22),
            child: const Padding(
              padding: EdgeInsets.all(17),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
