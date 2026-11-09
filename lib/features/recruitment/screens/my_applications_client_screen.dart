import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_application.dart';
import 'package:smartfood/features/recruitment/services/application_service.dart';
import 'package:smartfood/features/recruitment/services/recruitment_data.dart';
import 'package:smartfood/features/recruitment/widgets/status_badge.dart';

class MyApplicationsClientScreen extends StatefulWidget {
  const MyApplicationsClientScreen({super.key});

  @override
  State<MyApplicationsClientScreen> createState() =>
      _MyApplicationsClientScreenState();
}

class _MyApplicationsClientScreenState
    extends State<MyApplicationsClientScreen> {
  final _phoneController = TextEditingController();
  List<JobApplication>? _results;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _search() {
    final phone = _phoneController.text.trim();
    setState(() {
      _results = phone.isEmpty
          ? <JobApplication>[]
          : ApplicationService.instance.forPhone(phone);
    });
  }

  String _offerTitle(String offerId) {
    for (final o in RecruitmentData.offers) {
      if (o.id == offerId) return o.title;
    }
    return 'Offre';
  }

  String _message(String status) {
    if (status == ApplicationStatus.accepted) {
      return 'Félicitations ! Le restaurant vous contactera.';
    }
    if (status == ApplicationStatus.rejected) {
      return 'Votre candidature n’a pas été retenue.';
    }
    if (status == ApplicationStatus.shortlisted) {
      return 'Votre profil intéresse le restaurant.';
    }
    return 'Candidature en cours d’examen.';
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Mes candidatures'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Votre téléphone',
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: _search,
                    child: const Icon(Icons.search_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: results == null
                ? const Center(
              child: Text('Saisissez votre téléphone pour voir le suivi'),
            )
                : results.isEmpty
                ? const Center(child: Text('Aucune candidature trouvée'))
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: results.length,
              separatorBuilder: (_, __) =>
              const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = results[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _offerTitle(app.offerId),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          StatusBadge(status: app.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _message(app.status),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
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