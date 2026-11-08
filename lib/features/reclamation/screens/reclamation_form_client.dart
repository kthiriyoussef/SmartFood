import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/auth/services/session_service.dart';
import 'package:smartfood/features/reclamation/repositories/reclamation_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smartfood/features/reclamation/services/reclamation_ocr_service.dart';

class ReclamationFormScreen extends StatefulWidget {
  const ReclamationFormScreen({super.key});

  @override
  State<ReclamationFormScreen> createState() => _ReclamationFormScreenState();
}

class _ReclamationFormScreenState extends State<ReclamationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ReclamationRepository();
  final _ocrService = ReclamationOcrService();
  final _imagePicker = ImagePicker();

  bool _scanning = false;
  String? _ocrTexte;
  String? _ocrDate;
  String? _ocrMontant;
  String? _ocrReference;

  final _reservationController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _motifs = const [
    'Plat non conforme',
    'Annulation tardive',
    'Retrait refusé au comptoir',
    'Quantité incorrecte',
    'Commande payée non reçue',
    'Autre',
  ];

  String? _selectedMotif;
  String _selectedImpact = 'NORMAL';

  PlatformFile? _selectedFile;
  bool _saving = false;

  // ======================================
  // CALCUL AUTOMATIQUE DE LA PRIORITE
  // ======================================

  String? get _previewPriority {
    if (_selectedMotif == null) return null;

    return ReclamationRepository.calculatePriority(
      sujet: _selectedMotif!,
      impact: _selectedImpact,
      createdAt: DateTime.now(),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'FAIBLE':
        return 'Faible';
      case 'MOYENNE':
        return 'Moyenne';
      case 'ELEVEE':
        return 'Élevée';
      case 'URGENTE':
        return 'Urgente';
      default:
        return priority;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'FAIBLE':
        return Colors.green;
      case 'MOYENNE':
        return Colors.blue;
      case 'ELEVEE':
        return Colors.orange;
      case 'URGENTE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPriorityPreview() {
    final priority = _previewPriority;

    if (priority == null) {
      return const SizedBox.shrink();
    }

    final color = _priorityColor(priority);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Priorité calculée automatiquement',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _priorityLabel(priority),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'La priorité peut évoluer selon '
                  "l'ancienneté de la réclamation.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================
  // GESTION DES FICHIERS JUSTIFICATIFS
  // ======================================

  Future<void> _scannerTicket(ImageSource source) async {
    if (_scanning || _saving) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        _scanning = true;
      });

      final resultat = await _ocrService.scanner(image.path);

      if (!mounted) return;

      setState(() {
        _ocrTexte = resultat.texteComplet;
        _ocrReference = resultat.reference;
        _ocrDate = resultat.date;
        _ocrMontant = resultat.montant;
      });

      await _afficherResultatOCR(resultat);
    } catch (e) {
      if (!mounted) return;
      _message('Erreur du scanner OCR : $e');
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  Future<void> _afficherResultatOCR(
    ReclamationOcrResult resultat,
  ) async {
    final referenceController = TextEditingController(
      text: resultat.reference ?? '',
    );

    try {
      final confirmer = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.document_scanner, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Résultat du scan OCR')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Référence détectée',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: referenceController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Corriger ou saisir la référence',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Date : ${resultat.date ?? "Non détectée"}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Montant : ${resultat.montant ?? "Non détecté"}',
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Texte reconnu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    resultat.texteComplet,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vérifiez les informations avant de les utiliser.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.check),
                label: const Text('Utiliser'),
              ),
            ],
          );
        },
      );

      if (!mounted || confirmer != true) return;

      final reference = referenceController.text.trim();

      setState(() {
        _ocrReference = reference.isEmpty ? null : reference;

        if (reference.isNotEmpty) {
          _reservationController.text = reference;
        }
      });

      _message('Informations OCR vérifiées et récupérées.');
    } finally {
      referenceController.dispose();
    }
  }

  Future<void> _pickJustificatif() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
        ],
      );

      if (!mounted || files.isEmpty) return;

      final file = files.first;
      final path = file.path;

      if (path == null || path.isEmpty) {
        _message('Impossible de lire ce fichier.');
        return;
      }

      final selectedFile = File(path);

      if (!await selectedFile.exists()) {
        _message(
          'Le fichier sélectionné est introuvable.',
        );
        return;
      }

      final taille = await selectedFile.length();

      if (taille > 5 * 1024 * 1024) {
        _message(
          'Le fichier doit faire moins de 5 Mo.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedFile = file;
      });
    } catch (e) {
      if (mounted) {
        _message('Erreur de sélection : $e');
      }
    }
  }

  Future<String> _copyJustificatif(
    PlatformFile file,
    int userId,
  ) async {
    final directory = await getApplicationDocumentsDirectory();

    final folder = Directory(
      '${directory.path}/reclamations/$userId',
    );

    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }

    final extension = file.extension?.toLowerCase() ?? 'bin';

    final destination =
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.$extension';

    final copied = await File(
      file.path!,
    ).copy(destination);

    return copied.path;
  }

  // ======================================
  // MESSAGES
  // ======================================

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ======================================
  // ENREGISTREMENT DE LA RECLAMATION
  // ======================================

  Future<void> _submitReclamation() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    String? savedPath;

    try {
      final user = await SessionService.instance.restoreUser();

      if (user == null || user['role'] != 'CLIENT') {
        throw StateError(
          'Veuillez vous connecter comme CLIENT.',
        );
      }

      final userId = user['id'] as int;

      if (_selectedFile != null) {
        savedPath = await _copyJustificatif(
          _selectedFile!,
          userId,
        );
      }

      final id = await _repository.create(
        userId: userId,
        sujet: _selectedMotif!,
        description: _descriptionController.text,
        reservationRef: _reservationController.text,
        justificatifPath: savedPath,
        justificatifName: _selectedFile?.name,
        impact: _selectedImpact,
      );

      if (!mounted) return;

      Navigator.of(context).pop(id);
    } catch (e) {
      if (savedPath != null) {
        try {
          await File(savedPath).delete();
        } catch (_) {
          // Nettoyage non critique.
        }
      }

      if (mounted) {
        _message('Erreur : $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _reservationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ======================================
  // INTERFACE UTILISATEUR
  // ======================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Déposer une réclamation',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ==========================
              // EN-TETE
              // ==========================

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: Colors.white,
                      size: 36,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Un problème avec votre commande ?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Décrivez votre problème et '
                      'suivez son traitement.',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==========================
              // MOTIF DE RECLAMATION
              // ==========================

              DropdownButtonFormField<String>(
                initialValue: _selectedMotif,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Motif de réclamation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.report_problem_outlined,
                  ),
                ),
                items: _motifs.map((motif) {
                  return DropdownMenuItem<String>(
                    value: motif,
                    child: Text(
                      motif,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _selectedMotif = value;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return 'Sélectionnez un motif.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ==========================
              // IMPACT DU PROBLEME
              // ==========================

              Text(
                'Impact du problème',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 8),

              RadioGroup<String>(
                groupValue: _selectedImpact,
                onChanged: (value) {
                  if (value != null && !_saving) {
                    setState(() {
                      _selectedImpact = value;
                    });
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text(
                        'Impact normal',
                      ),
                      subtitle: const Text(
                        'Problème mineur ou limité',
                      ),
                      value: 'NORMAL',
                      enabled: !_saving,
                      activeColor: AppColors.primary,
                    ),
                    RadioListTile<String>(
                      title: const Text(
                        'Impact important',
                      ),
                      subtitle: const Text(
                        'Paiement, commande perdue '
                        'ou problème important',
                      ),
                      value: 'FORT',
                      enabled: !_saving,
                      activeColor: Colors.red,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ==========================
              // PRIORITE AUTOMATIQUE
              // ==========================

              _buildPriorityPreview(),

              const SizedBox(height: 20),

              // ==========================
              // REFERENCE RESERVATION
              // ==========================

              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.document_scanner_outlined,
                            color: Colors.green,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Scanner intelligent OCR',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Scannez votre ticket pour récupérer '
                        'automatiquement ses informations.',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _scanning || _saving
                                  ? null
                                  : () => _scannerTicket(
                                        ImageSource.camera,
                                      ),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Caméra'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _scanning || _saving
                                  ? null
                                  : () => _scannerTicket(
                                        ImageSource.gallery,
                                      ),
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Galerie'),
                            ),
                          ),
                        ],
                      ),
                      if (_scanning) ...[
                        const SizedBox(height: 14),
                        const Center(
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text('Analyse du ticket en cours...'),
                        ),
                      ],
                      if (_ocrTexte != null && !_scanning) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Dernier ticket analysé',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Référence : ${_ocrReference ?? "Non détectée"}',
                        ),
                        Text('Date : ${_ocrDate ?? "Non détectée"}'),
                        Text('Montant : ${_ocrMontant ?? "Non détecté"}'),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _reservationController,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Référence réservation (optionnelle)',
                  hintText: 'Ex : R-204',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================
              // DESCRIPTION
              // ==========================

              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Expliquez votre problème...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 10) {
                    return 'Minimum 10 caractères.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ==========================
              // JUSTIFICATIF
              // ==========================

              OutlinedButton.icon(
                onPressed: _saving ? null : _pickJustificatif,
                icon: const Icon(
                  Icons.attach_file,
                ),
                label: Text(
                  _selectedFile?.name ?? 'Ajouter une photo ou un PDF',
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (_selectedFile != null)
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          setState(() {
                            _selectedFile = null;
                          });
                        },
                  icon: const Icon(
                    Icons.close,
                  ),
                  label: const Text(
                    'Retirer le justificatif',
                  ),
                ),

              const SizedBox(height: 8),

              const Text(
                'Formats acceptés : '
                'JPG, PNG, PDF — maximum 5 Mo.',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 24),

              // ==========================
              // BOUTON ENVOYER
              // ==========================

              FilledButton.icon(
                onPressed: _saving ? null : _submitReclamation,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                      ),
                label: Text(
                  _saving ? 'Enregistrement...' : 'Envoyer la réclamation',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
