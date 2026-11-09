import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/screens/job_offer_details_client.dart';
import 'package:smartfood/features/recruitment/screens/my_applications_client_screen.dart';
import 'package:smartfood/features/recruitment/services/recruitment_data.dart';
import 'package:smartfood/features/recruitment/widgets/job_offer_card.dart';

class JobOfferListClientScreen extends StatelessWidget {
  const JobOfferListClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Offres disponibles'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MyApplicationsClientScreen(),
              ),
            ),
            icon: const Icon(Icons.assignment_ind_outlined),
            label: const Text('Mes candidatures'),
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: RecruitmentData.changes,
        builder: (context, _, __) {
          final offers =
          RecruitmentData.offers.where((o) => o.isActive).toList();

          if (offers.isEmpty) {
            return const Center(child: Text('Aucune offre disponible'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: offers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return JobOfferCard(
                offer: offer,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => JobOfferDetailsClientScreen(offer: offer),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}