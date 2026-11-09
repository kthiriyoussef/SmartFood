import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';
import 'package:smartfood/features/recruitment/screens/job_application_form_client.dart';

class JobOfferDetailsClientScreen extends StatelessWidget {
  const JobOfferDetailsClientScreen({super.key, required this.offer});

  final JobOffer offer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Détail de l’offre'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 16),
              Text(
                offer.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.payments_outlined,
                      size: 20, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Text(
                    offer.salary ?? 'Salaire non précisé',
                    style:
                    textTheme.bodyLarge?.copyWith(color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Prérequis',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                offer.requirements ?? 'Aucun prérequis précisé',
                style: textTheme.bodyMedium
                    ?.copyWith(color: AppColors.muted, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  // Règle métier : pas de candidature sur une offre fermée.
                  onPressed: offer.isActive
                      ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          JobApplicationFormScreen(offer: offer),
                    ),
                  )
                      : null,
                  icon: const Icon(Icons.send_rounded),
                  label: Text(offer.isActive ? 'Postuler' : 'Offre fermée'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}