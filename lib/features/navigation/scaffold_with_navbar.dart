import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
              icon: Icon(LucideIcons.house, size: 23),
              selectedIcon: Icon(LucideIcons.house, color: AppColors.primary, size: 23),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.receipt, size: 23),
              selectedIcon: Icon(LucideIcons.receipt, color: AppColors.primary, size: 23),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.chartColumn, size: 23),
              selectedIcon: Icon(LucideIcons.chartColumn, color: AppColors.primary, size: 23),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.handshake, size: 23),
              selectedIcon: Icon(LucideIcons.handshake, color: AppColors.primary, size: 23),
              label: 'Dues',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.slidersHorizontal, size: 23),
              selectedIcon: Icon(LucideIcons.slidersHorizontal, color: AppColors.primary, size: 23),
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
              child: Icon(LucideIcons.plus, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
