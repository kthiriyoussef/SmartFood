import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';
import 'package:smartfood/features/recruitment/screens/job_application_list_restaurant.dart';
import 'package:smartfood/features/recruitment/screens/job_offer_form_restaurant.dart';
import 'package:smartfood/features/recruitment/services/application_service.dart';
import 'package:smartfood/features/recruitment/services/recruitment_data.dart';
import 'package:smartfood/features/recruitment/widgets/job_offer_card.dart';

class JobOfferListScreen extends StatefulWidget {
  const JobOfferListScreen({super.key});

  @override
  State<JobOfferListScreen> createState() => _JobOfferListScreenState();
}

class _JobOfferListScreenState extends State<JobOfferListScreen> {
  // Liste partagée avec l'espace client.
  final List<JobOffer> _offers = RecruitmentData.offers;

  Future<void> _openForm() async {
    final newOffer = await Navigator.of(context).push<JobOffer>(
      MaterialPageRoute(builder: (_) => const JobOfferFormScreen()),
    );

    if (newOffer == null || !mounted) return;

    RecruitmentData.addOffer(newOffer);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offre publiée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mes offres d’emploi'),
      ),
      body: _offers.isEmpty
          ? const Center(child: Text('Aucune offre pour le moment'))
          : ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _offers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final offer = _offers[index];
          return JobOfferCard(
            offer: offer,
            applicationsCount:
            ApplicationService.instance.countForOffer(offer.id),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JobApplicationListScreen(offer: offer),
                ),
              );
              if (mounted) setState(() {});
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter une offre'),
      ),
    );
  }
}