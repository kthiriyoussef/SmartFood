import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_application.dart';
import 'package:smartfood/features/recruitment/services/application_service.dart';
import 'package:smartfood/features/recruitment/widgets/status_badge.dart';

class JobApplicationDetailsScreen extends StatefulWidget {
  const JobApplicationDetailsScreen({super.key, required this.applicationId});

  final String applicationId;

  @override
  State<JobApplicationDetailsScreen> createState() =>
      _JobApplicationDetailsScreenState();
}

class _JobApplicationDetailsScreenState
    extends State<JobApplicationDetailsScreen> {
  final _service = ApplicationService.instance;

  JobApplication get _app =>
      _service.all.firstWhere((a) => a.id == widget.applicationId);

  static const _labels = {
    ApplicationStatus.shortlisted: 'Mettre en retenue',
    ApplicationStatus.accepted: 'Accepter',
    ApplicationStatus.rejected: 'Refuser',
  };

  void _change(String newStatus) {
    final error = _service.changeStatus(widget.applicationId, newStatus);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    final next = _service.allowedNext(app.status);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Détail candidature'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    app.candidateName,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                StatusBadge(status: app.status),
              ],
            ),
            const SizedBox(height: 20),
            _info(Icons.phone_outlined, app.phoneNumber ?? 'Non renseigné'),
            const SizedBox(height: 12),
            _info(Icons.description_outlined, app.cvUrl ?? 'Pas de CV'),
            const SizedBox(height: 24),
            Text('Motivation',
                style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            Text(
              app.motivation ?? 'Aucun message',
              style: textTheme.bodyMedium
                  ?.copyWith(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (next.isEmpty)
              Text(
                'Statut final : aucune action possible.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              )
            else
              ...next.map(
                    (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: s == ApplicationStatus.rejected
                            ? AppColors.error
                            : AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => _change(s),
                      child: Text(_labels[s] ?? s),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: AppColors.text)),
        ),
      ],
    );
  }
}