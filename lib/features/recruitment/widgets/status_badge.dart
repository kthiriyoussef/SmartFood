import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_application.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final meta = _meta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: meta.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        meta.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: meta.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _Meta _meta(String status) {
    switch (status) {
      case ApplicationStatus.accepted:
        return _Meta('Accepté', AppColors.success.withValues(alpha: 0.12),
            AppColors.primary);
      case ApplicationStatus.rejected:
        return _Meta('Refusé', AppColors.error.withValues(alpha: 0.12),
            AppColors.error);
      case ApplicationStatus.shortlisted:
        return _Meta('En retenue', AppColors.warning.withValues(alpha: 0.16),
            AppColors.warning);
      case ApplicationStatus.received:
      default:
        return _Meta('Reçu', AppColors.warning.withValues(alpha: 0.14),
            AppColors.warning);
    }
  }
}

class _Meta {
  const _Meta(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}