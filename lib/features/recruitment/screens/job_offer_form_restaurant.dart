import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/recruitment/models/job_offer.dart';
import 'package:smartfood/features/recruitment/models/skills.dart';

class JobOfferFormScreen extends StatefulWidget {
  const JobOfferFormScreen({super.key});

  @override
  State<JobOfferFormScreen> createState() => _JobOfferFormScreenState();
}

class _JobOfferFormScreenState extends State<JobOfferFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();
  String _contractType = 'CDI';
  int _minExperience = 0;
  final Set<String> _skills = {};

  @override
  void dispose() {
    _titleController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_skills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Choisissez au moins une compétence requise'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final offer = JobOffer(
      id: 'O-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      contractType: _contractType,
      salary: _salaryController.text.trim().isEmpty
          ? null
          : _salaryController.text.trim(),
      requirements: _requirementsController.text.trim().isEmpty
          ? null
          : _requirementsController.text.trim(),
      requiredSkills: _skills.toList(),
      minExperienceYears: _minExperience,
    );

    Navigator.of(context).pop(offer);
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
        title: const Text('Nouvelle offre'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: _decoration('Intitulé du poste',
                    hint: 'Ex : Serveur / Serveuse'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Veuillez saisir l’intitulé du poste'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _contractType,
                decoration: _decoration('Type de contrat'),
                items: const [
                  DropdownMenuItem(value: 'CDI', child: Text('CDI')),
                  DropdownMenuItem(value: 'CDD', child: Text('CDD')),
                  DropdownMenuItem(value: 'EXTRA', child: Text('Extra')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _contractType = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                decoration: _decoration('Salaire indicatif',
                    hint: 'Ex : 900 DT / mois'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _requirementsController,
                maxLines: 3,
                decoration: _decoration('Description / prérequis'),
              ),
              const SizedBox(height: 24),
              Text('Compétences requises',
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
              Text('Expérience minimale : $_minExperience an(s)',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.text)),
              Slider(
                value: _minExperience.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$_minExperience',
                onChanged: (v) => setState(() => _minExperience = v.round()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Publier l’offre'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}