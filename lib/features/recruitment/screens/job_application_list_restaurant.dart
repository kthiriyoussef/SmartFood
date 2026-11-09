import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_application.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';
import 'package:smartfood/features/recruitment/screens/job_application_details_restaurant.dart';
import 'package:smartfood/features/recruitment/services/application_service.dart';
import 'package:smartfood/features/recruitment/services/recruitment_data.dart';
import 'package:smartfood/features/recruitment/widgets/status_badge.dart';

class JobApplicationListScreen extends StatefulWidget {
  const JobApplicationListScreen({super.key, required this.offer});

  final JobOffer offer;

  @override
  State<JobApplicationListScreen> createState() =>
      _JobApplicationListScreenState();
}

class _JobApplicationListScreenState extends State<JobApplicationListScreen> {
  String? _filter; // null = toutes

  static const _filters = <String?, String>{
    null: 'Toutes',
    ApplicationStatus.received: 'Reçues',
    ApplicationStatus.shortlisted: 'En retenue',
    ApplicationStatus.accepted: 'Acceptées',
    ApplicationStatus.rejected: 'Refusées',
  };

  /// Version à jour de l'offre (son statut peut changer).
  JobOffer get _offer => RecruitmentData.offers
      .firstWhere((o) => o.id == widget.offer.id, orElse: () => widget.offer);

  void _toggleOffer() {
    final newState = !_offer.isActive;
    RecruitmentData.setActive(widget.offer.id, newState);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newState ? 'Offre rouverte' : 'Offre fermée'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;
    final all = ApplicationService.instance.forOffer(offer.id);
    final list =
    _filter == null ? all : all.where((a) => a.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Candidatures • ${offer.title}'),
        actions: [
          TextButton.icon(
            onPressed: _toggleOffer,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: Icon(offer.isActive
                ? Icons.lock_outline_rounded
                : Icons.lock_open_rounded),
            label: Text(offer.isActive ? 'Fermer' : 'Rouvrir'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!offer.isActive)
            Container(
              width: double.infinity,
              color: AppColors.error.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
              child: Text(
                'Offre fermée : les candidats ne peuvent plus postuler.',
                style: TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: _filters.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _filter == e.key,
                    onSelected: (_) => setState(() => _filter = e.key),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Aucune candidature'))
                : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = list[index];
                return Material(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => JobApplicationDetailsScreen(
                              applicationId: app.id),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.candidateName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  app.phoneNumber ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: app.status),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}