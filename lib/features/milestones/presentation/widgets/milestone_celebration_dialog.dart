import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/milestones_provider.dart';

class MilestoneCelebrationDialog extends StatelessWidget {
  final MilestoneInfo milestone;
  final VoidCallback onDismiss;

  const MilestoneCelebrationDialog({
    super.key,
    required this.milestone,
    required this.onDismiss,
  });

  static void show(BuildContext context, MilestoneInfo milestone, VoidCallback onDismiss) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => MilestoneCelebrationDialog(
        milestone: milestone,
        onDismiss: onDismiss,
      ),
    );
  }

  IconData _getIcon() {
    switch (milestone.iconType) {
      case 'flame':
        return LucideIcons.flame;
      case 'trophy':
        return LucideIcons.trophy;
      case 'shield':
        return LucideIcons.shieldCheck;
      case 'sparkles':
      default:
        return LucideIcons.sparkles;
    }
  }

  Color _getAccentColor() {
    switch (milestone.iconType) {
      case 'flame':
        return AppColors.primary;
      case 'trophy':
        return AppColors.warning;
      case 'shield':
        return AppColors.income;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = _getAccentColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.25 : 0.15),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebratory Icon with Glow
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accent.withValues(alpha: 0.4),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Icon(_getIcon(), size: 44, color: accent),
              ),
            ),
            const SizedBox(height: 20),

            // Badge pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'MILESTONE ACHIEVED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Headline
            Text(
              milestone.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              milestone.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDismiss();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Nice! 🎉', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

