import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reclamation/models/reclamation.dart';

class ReclamationCard extends StatelessWidget {
  const ReclamationCard({
    super.key,
    required this.reclamation,
    this.onTap,
  });

  final Reclamation reclamation;
  final VoidCallback? onTap;

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'URGENTE':
        return Colors.red;
      case 'ELEVEE':
        return Colors.orange;
      case 'MOYENNE':
        return Colors.blue;
      case 'FAIBLE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'URGENTE':
        return 'URGENTE';
      case 'ELEVEE':
        return 'ÉLEVÉE';
      case 'MOYENNE':
        return 'MOYENNE';
      case 'FAIBLE':
        return 'FAIBLE';
      default:
        return priority;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'EN_ATTENTE':
        return 'En attente';
      case 'EN_COURS':
        return 'En cours';
      case 'RESOLUE':
        return 'Résolue';
      case 'REJETEE':
        return 'Rejetée';
      case 'ESCALADEE':
        return 'Escaladée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESOLUE':
        return Colors.green;
      case 'REJETEE':
        return Colors.red;
      case 'EN_COURS':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = reclamation.priorite;
    final priorityColor = _priorityColor(priority);

    final status = reclamation.status;
    final statusColor = _statusColor(status);

    final restaurantName = reclamation.restaurantName ?? 'Restaurant SmartFood';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: priority == 'URGENTE'
                  ? Colors.red.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.04),
              width: priority == 'URGENTE' ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IDENTIFIANT ET STATUT
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ticket ${reclamation.id}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // PRIORITE AUTOMATIQUE
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      priority == 'URGENTE'
                          ? Icons.priority_high
                          : Icons.auto_awesome,
                      color: priorityColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Priorité ${_priorityLabel(priority)}',
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // MOTIF
              Row(
                children: [
                  const Icon(
                    Icons.report_problem_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reclamation.motif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // DESCRIPTION
              Text(
                reclamation.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
              ),

              const SizedBox(height: 12),

              // IMPACT
              Row(
                children: [
                  Icon(
                    reclamation.impact == 'FORT'
                        ? Icons.warning_amber
                        : Icons.info_outline,
                    size: 18,
                    color: reclamation.impact == 'FORT'
                        ? Colors.orange
                        : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reclamation.impactLabel,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // RESTAURANT ET DATE
              Row(
                children: [
                  const Icon(
                    Icons.store_mall_directory_outlined,
                    size: 18,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.text,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.access_time_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reclamation.createdAt,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
