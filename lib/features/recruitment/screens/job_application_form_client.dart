import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_application.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';
import 'package:smartfood/features/recruitment/models/skills.dart';
import 'package:smartfood/features/recruitment/services/application_service.dart';

class JobApplicationFormScreen extends StatefulWidget {
  const JobApplicationFormScreen({super.key, required this.offer});

  final JobOffer offer;

  @override
  State<JobApplicationFormScreen> createState() =>
      _JobApplicationFormScreenState();
}

class _JobApplicationFormScreenState extends State<JobApplicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cvController = TextEditingController();
  final _motivationController = TextEditingController();
  final Set<String> _skills = {};
  int _experience = 0;
  String _availability = Availability.fullTime;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cvController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final application = JobApplication(
      id: 'A-${DateTime.now().millisecondsSinceEpoch}',
      offerId: widget.offer.id,
      candidateName: _nameController.text.trim(),
      status: ApplicationStatus.received,
      phoneNumber: _phoneController.text.trim(),
      cvUrl: _cvController.text.trim().isEmpty
          ? null
          : _cvController.text.trim(),
      motivation: _motivationController.text.trim().isEmpty
          ? null
          : _motivationController.text.trim(),
      skills: _skills.toList(),
      experienceYears: _experience,
      availability: _availability,
    );

    final error = ApplicationService.instance.submit(application);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Candidature envoyée')),
    );
    Navigator.of(context).pop();
  }

  InputDecoration _decoration(String label, {String? hint}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.card,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Postuler'),
      ),
      // Bouton fixe, toujours visible en bas de l'écran.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Envoyer ma candidature'),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.offer.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: _decoration('Nom complet'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez saisir votre nom'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Téléphone', hint: 'Ex : 22123456'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Veuillez saisir votre téléphone';
                  if (!RegExp(r'^\+?\d{8,12}$').hasMatch(value)) {
                    return 'Numéro invalide (8 à 12 chiffres)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cvController,
                decoration: _decoration('Lien du CV (optionnel)'),
              ),
              const SizedBox(height: 24),
              Text('Vos compétences',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: Skills.all.map((s) {
                  return FilterChip(
                    label: Text(s),
                    selected: _skills.contains(s),
                    onSelected: (selected) => setState(() {
                      selected ? _skills.add(s) : _skills.remove(s);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              Text('Années d’expérience : $_experience',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.text)),
              Slider(
                value: _experience.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$_experience',
                onChanged: (v) => setState(() => _experience = v.round()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _availability,
                decoration: _decoration('Disponibilité'),
                items: Availability.labels.entries
                    .map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _availability = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivationController,
                maxLines: 4,
                decoration: _decoration('Message de motivation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}