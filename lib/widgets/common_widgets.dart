import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/models.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.title, required this.value,
    required this.icon, required this.color, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool compact;
  const StatusBadge({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(width: 12, height: 12,
        decoration: BoxDecoration(color: status.color, shape: BoxShape.circle));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: status.color),
          const SizedBox(width: 4),
          Text(status.label, style: TextStyle(fontSize: 11, color: status.color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined,
    this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16), textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!, style: const TextStyle(color: AppColors.primary))),
      ],
    );
  }
}

Future<bool> showConfirmDialog(BuildContext context, {
  required String title, required String message,
  String confirmLabel = 'Supprimer', Color confirmColor = AppColors.absent,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ===== ORG SWITCHER CHIP =====
class OrgSwitcherChip extends StatelessWidget {
  final String orgName;
  final Color orgColor;
  final VoidCallback onTap;

  const OrgSwitcherChip({super.key, required this.orgName, required this.orgColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white38),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: orgColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(orgName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.unfold_more, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
