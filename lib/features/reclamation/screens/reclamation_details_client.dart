import 'dart:io';

import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reclamation/models/reclamation.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_chat_screen.dart';

class ReclamationDetailScreen extends StatelessWidget {
  const ReclamationDetailScreen({
    super.key,
    required this.reclamation,
  });

  final Reclamation reclamation;

  String _statusLabel(String status) {
    switch (status) {
      case 'EN_ATTENTE':
        return 'En attente';
      case 'EN_COURS':
        return 'En cours de traitement';
      case 'RESOLUE':
        return 'Résolue';
      case 'REJETEE':
        return 'Rejetée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESOLUE':
        return Colors.green;
      case 'REJETEE':
        return Colors.red;
      case 'EN_COURS':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
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

  String _impactLabel(String impact) {
    return impact == 'FORT' ? 'Impact important' : 'Impact normal';
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _prioritySection() {
    final priority = reclamation.priorite;
    final color = _priorityColor(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Priorité automatique',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    priority == 'URGENTE'
                        ? Icons.priority_high
                        : Icons.auto_awesome,
                    color: color,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _priorityLabel(priority),
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _impactLabel(reclamation.impact),
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cette priorité est déterminée '
              'automatiquement selon le motif, '
              "l'impact et l'ancienneté du problème.",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachment() {
    final path = reclamation.justificatifPath;

    if (path == null || path.isEmpty) {
      return const Text('Aucun justificatif joint.');
    }

    final file = File(path);

    final isImage = [
      '.jpg',
      '.jpeg',
      '.png',
    ].any(
      (extension) => path.toLowerCase().endsWith(extension),
    );

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const CircularProgressIndicator();
        }

        if (snapshot.data != true) {
          return const Text(
            'Le fichier justificatif est introuvable.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reclamation.justificatifName ?? 'Justificatif',
            ),
            const SizedBox(height: 12),
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              )
            else
              const ListTile(
                leading: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.red,
                ),
                title: Text(
                  'Document PDF enregistré',
                ),
                subtitle: Text(
                  'Le document est conservé '
                  'dans SmartFood.',
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = reclamation.status;
    final color = _statusColor(status);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détails réclamation'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // EN-TETE
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ticket ${reclamation.id}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  reclamation.motif,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Chip(
                  label: Text(_statusLabel(status)),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // PRIORITE
          _prioritySection(),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discussion avec le support',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Échangez avec un administrateur concernant '
                    'cette réclamation sans créer un nouveau ticket.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final ticketId = int.tryParse(
                          reclamation.id.replaceFirst('T-', ''),
                        );

                        if (ticketId == null) return;

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReclamationChatScreen(
                              reclamationId: ticketId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Ouvrir la discussion'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // INFORMATIONS
          _section(
            'Informations',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date : ${reclamation.createdAt}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Réservation : '
                  '${reclamation.reservationRef ?? 'Non renseignée'}',
                ),
              ],
            ),
          ),

          // DESCRIPTION
          _section(
            'Votre message',
            Text(reclamation.description),
          ),

          // SUIVI
          _section(
            'Suivi du traitement',
            Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Réclamation envoyée',
                  ),
                  subtitle: Text(
                    reclamation.createdAt,
                  ),
                ),
                ListTile(
                  leading: Icon(
                    status == 'EN_ATTENTE'
                        ? Icons.hourglass_empty
                        : Icons.check_circle,
                    color:
                        status == 'EN_ATTENTE' ? Colors.orange : Colors.green,
                  ),
                  title: const Text(
                    'Prise en charge',
                  ),
                  subtitle: Text(
                    _statusLabel(status),
                  ),
                ),
                if (status == 'RESOLUE' || status == 'REJETEE')
                  ListTile(
                    leading: Icon(
                      status == 'RESOLUE'
                          ? Icons.task_alt
                          : Icons.cancel_outlined,
                      color: color,
                    ),
                    title: Text(
                      _statusLabel(status),
                    ),
                  ),
              ],
            ),
          ),

          // JUSTIFICATIF
          _section(
            'Justificatif',
            _attachment(),
          ),
        ],
      ),
    );
  }
}
