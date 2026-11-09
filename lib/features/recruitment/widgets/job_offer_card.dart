import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';

class JobOfferCard extends StatelessWidget {
  const JobOfferCard({
    super.key,
    required this.offer,
    this.onTap,
    this.applicationsCount,
  });

  final JobOffer offer;
  final VoidCallback? onTap;
  final int? applicationsCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
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
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      offer.contractType,
                      style: textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    offer.isActive ? 'Active' : 'Fermée',
                    style: textTheme.labelSmall?.copyWith(
                      color:
                      offer.isActive ? AppColors.primary : AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                offer.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (offer.requirements != null) ...[
                const SizedBox(height: 8),
                Text(
                  offer.requirements!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 18, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Text(
                    offer.salary ?? 'Salaire non précisé',
                    style:
                    textTheme.bodyMedium?.copyWith(color: AppColors.text),
                  ),
                  const Spacer(),
                  Icon(Icons.people_outline, size: 18, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    '${applicationsCount ?? offer.applicationsCount}',
                    style:
                    textTheme.bodyMedium?.copyWith(color: AppColors.text),
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