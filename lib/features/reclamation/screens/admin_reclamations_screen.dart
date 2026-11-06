import 'package:flutter/material.dart';

import 'package:smartfood/features/reclamation/repositories/reclamation_repository.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_chat_screen.dart';

class AdminReclamationsScreen extends StatefulWidget {
  const AdminReclamationsScreen({
    super.key,
    required this.adminId,
  });

  final int adminId;

  @override
  State<AdminReclamationsScreen> createState() =>
      _AdminReclamationsScreenState();
}

class _AdminReclamationsScreenState extends State<AdminReclamationsScreen> {
  final ReclamationRepository _repository = ReclamationRepository();

  List<Map<String, Object?>> _reclamations = [];

  bool _loading = true;
  String? _error;

  String _statusFilter = 'TOUTES';
  String _priorityFilter = 'TOUTES';

  static const Map<String, String> _statuses = {
    'EN_ATTENTE': 'En attente',
    'EN_COURS': 'En cours',
    'RESOLUE': 'Résolue',
    'REJETEE': 'Rejetée',
  };

  static const Map<String, String> _priorities = {
    'URGENTE': 'Urgente',
    'ELEVEE': 'Élevée',
    'MOYENNE': 'Moyenne',
    'FAIBLE': 'Faible',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ==========================================
  // CHARGEMENT DES RECLAMATIONS
  // ==========================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _repository.allForAdmin(
        adminId: widget.adminId,
      );

      if (!mounted) return;

      setState(() {
        _reclamations = rows;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ==========================================
  // PRIORITES
  // ==========================================

  String _priorityOf(Map<String, Object?> row) {
    return row['priorite']?.toString() ?? 'MOYENNE';
  }

  String _impactOf(Map<String, Object?> row) {
    return row['impact']?.toString() ?? 'NORMAL';
  }

  int _priorityRank(String priority) {
    switch (priority) {
      case 'URGENTE':
        return 4;
      case 'ELEVEE':
        return 3;
      case 'MOYENNE':
        return 2;
      case 'FAIBLE':
        return 1;
      default:
        return 0;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'URGENTE':
        return Colors.red;
      case 'ELEVEE':
        return Colors.orange;
      case 'MOYENNE':
        return Colors.blue;
      case 'FAIBLE':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'URGENTE':
        return Icons.priority_high;
      case 'ELEVEE':
        return Icons.warning_amber_rounded;
      case 'MOYENNE':
        return Icons.info_outline;
      case 'FAIBLE':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Widget _priorityBadge(String priority) {
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _priorityIcon(priority),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            _priorities[priority] ?? priority,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STATUTS
  // ==========================================

  bool _isOpen(String status) {
    return status == 'EN_ATTENTE' || status == 'EN_COURS';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'RESOLUE':
        return Colors.green;
      case 'REJETEE':
        return Colors.red;
      case 'EN_COURS':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statuses[status] ?? status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  // ==========================================
  // FILTRES ET TRI
  // ==========================================

  List<Map<String, Object?>> get _filtered {
    final items = _reclamations.where((row) {
      final status = row['statut']?.toString() ?? 'EN_ATTENTE';

      final priority = _priorityOf(row);

      final matchesStatus =
          _statusFilter == 'TOUTES' || status == _statusFilter;

      final matchesPriority =
          _priorityFilter == 'TOUTES' || priority == _priorityFilter;

      return matchesStatus && matchesPriority;
    }).toList();

    items.sort((a, b) {
      final statusA = a['statut']?.toString() ?? 'EN_ATTENTE';
      final statusB = b['statut']?.toString() ?? 'EN_ATTENTE';

      // Les reclamations ouvertes passent d'abord.
      final openA = _isOpen(statusA) ? 1 : 0;
      final openB = _isOpen(statusB) ? 1 : 0;

      final openComparison = openB.compareTo(openA);

      if (openComparison != 0) {
        return openComparison;
      }

      // Puis classement par priorite.
      final rankA = _priorityRank(_priorityOf(a));
      final rankB = _priorityRank(_priorityOf(b));

      final priorityComparison = rankB.compareTo(rankA);

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      // Enfin, les tickets les plus recents.
      final dateA = a['date_creation']?.toString() ?? '';
      final dateB = b['date_creation']?.toString() ?? '';

      return dateB.compareTo(dateA);
    });

    return items;
  }

  int get _urgentCount {
    return _reclamations.where((row) {
      final status = row['statut']?.toString() ?? 'EN_ATTENTE';

      return _isOpen(status) && _priorityOf(row) == 'URGENTE';
    }).length;
  }

  int get _pendingCount {
    return _reclamations.where((row) {
      return row['statut'] == 'EN_ATTENTE';
    }).length;
  }

  // ==========================================
  // MODIFICATION DU STATUT
  // ==========================================

  Future<void> _updateStatus(
    int reclamationId,
    String newStatus,
  ) async {
    try {
      await _repository.updateStatus(
        adminId: widget.adminId,
        reclamationId: reclamationId,
        statut: newStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Statut de la réclamation mis à jour.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // DETAILS ET TRAITEMENT
  // ==========================================

  Future<void> _showDetails(
    Map<String, Object?> reclamation,
  ) async {
    final id = reclamation['id'] as int;

    final currentStatus = reclamation['statut']?.toString() ?? 'EN_ATTENTE';

    final priority = _priorityOf(reclamation);
    final impact = _impactOf(reclamation);

    String selectedStatus = currentStatus;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Réclamation T-$id'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reclamation['sujet']?.toString() ?? 'Sans sujet',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // PRIORITE
                      const Text(
                        'Priorité automatique',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      _priorityBadge(priority),

                      const SizedBox(height: 12),

                      Text(
                        'Impact : ${impact == 'FORT' ? 'Important' : 'Normal'}',
                      ),

                      const SizedBox(height: 12),

                      _statusBadge(currentStatus),

                      const Divider(height: 28),

                      Text(
                        'Client ID : '
                        '${reclamation['user_id']}',
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Date : '
                        '${reclamation['date_creation'] ?? ''}',
                      ),

                      const Divider(height: 28),

                      const Text(
                        'Description',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        reclamation['description']?.toString() ?? '',
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Réservation : '
                        '${reclamation['reservation_ref'] ?? 'Non renseignée'}',
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Justificatif : '
                        '${reclamation['justificatif_name'] ?? 'Aucun'}',
                      ),

                      const Divider(height: 28),

                      const Text(
                        'Modifier le statut',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedStatus),
                        initialValue: selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: _statuses.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() {
                              selectedStatus = value;
                            });
                          }
                        },
                      ),

                      if (priority == 'URGENTE' && _isOpen(currentStatus)) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Réclamation urgente : '
                                  'traitement prioritaire recommandé.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: selectedStatus == currentStatus
                      ? null
                      : () {
                          Navigator.pop(
                            dialogContext,
                            selectedStatus,
                          );
                        },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    await _updateStatus(id, result);
  }

  // ==========================================
  // FILTRES VISUELS
  // ==========================================

  Widget _filterChip(
    String label,
    String value, {
    required bool isPriority,
  }) {
    final selected =
        isPriority ? _priorityFilter == value : _statusFilter == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Colors.green.shade100,
        onSelected: (_) {
          setState(() {
            if (isPriority) {
              _priorityFilter = value;
            } else {
              _statusFilter = value;
            }
          });
        },
      ),
    );
  }

  // ==========================================
  // STATISTIQUES
  // ==========================================

  Widget _statCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CARTE RECLAMATION
  // ==========================================

  Widget _reclamationCard(
    Map<String, Object?> reclamation,
  ) {
    final id = reclamation['id'];

    final status = reclamation['statut']?.toString() ?? 'EN_ATTENTE';

    final priority = _priorityOf(reclamation);
    final impact = _impactOf(reclamation);

    final isUrgentOpen = priority == 'URGENTE' && _isOpen(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isUrgentOpen
              ? Colors.red.withValues(alpha: 0.6)
              : Colors.transparent,
          width: isUrgentOpen ? 1.5 : 0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetails(reclamation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ticket T-$id',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  _priorityBadge(priority),
                ],
              ),
              const SizedBox(height: 12),
              _statusBadge(status),
              const SizedBox(height: 12),
              Text(
                reclamation['sujet']?.toString() ?? 'Sans sujet',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reclamation['description']?.toString() ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    impact == 'FORT' ? Icons.warning_amber : Icons.info_outline,
                    size: 18,
                    color: impact == 'FORT' ? Colors.orange : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    impact == 'FORT' ? 'Impact important' : 'Impact normal',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Client ID : '
                '${reclamation['user_id']}',
              ),
              const SizedBox(height: 6),
              Text(
                'Date : '
                '${reclamation['date_creation'] ?? ''}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 12),

// BOUTON DISCUSSION ADMIN / CLIENT
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ticketId = reclamation['id'] as int;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReclamationChatScreen(
                          reclamationId: ticketId,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Discuter avec le client'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Voir les détails et traiter',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // INTERFACE ADMIN
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des réclamations',
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // STATISTIQUES
          Padding(
            padding: const EdgeInsets.fromLTRB(
              12,
              12,
              12,
              4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _statCard(
                    title: 'Total',
                    count: _reclamations.length,
                    icon: Icons.support_agent,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _statCard(
                    title: 'Urgentes ouvertes',
                    count: _urgentCount,
                    icon: Icons.priority_high,
                    color: Colors.red,
                  ),
                ),
                Expanded(
                  child: _statCard(
                    title: 'En attente',
                    count: _pendingCount,
                    icon: Icons.hourglass_empty,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // FILTRES PAR STATUT
          const Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filtrer par statut',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              children: [
                _filterChip(
                  'Toutes',
                  'TOUTES',
                  isPriority: false,
                ),
                _filterChip(
                  'En attente',
                  'EN_ATTENTE',
                  isPriority: false,
                ),
                _filterChip(
                  'En cours',
                  'EN_COURS',
                  isPriority: false,
                ),
                _filterChip(
                  'Résolues',
                  'RESOLUE',
                  isPriority: false,
                ),
                _filterChip(
                  'Rejetées',
                  'REJETEE',
                  isPriority: false,
                ),
              ],
            ),
          ),

          // FILTRES PAR PRIORITE
          const Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Filtrer par priorité',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              children: [
                _filterChip(
                  'Toutes',
                  'TOUTES',
                  isPriority: true,
                ),
                _filterChip(
                  'Urgentes',
                  'URGENTE',
                  isPriority: true,
                ),
                _filterChip(
                  'Élevées',
                  'ELEVEE',
                  isPriority: true,
                ),
                _filterChip(
                  'Moyennes',
                  'MOYENNE',
                  isPriority: true,
                ),
                _filterChip(
                  'Faibles',
                  'FAIBLE',
                  isPriority: true,
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sort,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tickets ouverts et urgents en premier',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Text(
                  '${items.length} résultat(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // LISTE
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Erreur : $_error',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _load,
                                child: const Text(
                                  'Réessayer',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: items.isEmpty
                            ? ListView(
                                children: const [
                                  SizedBox(height: 100),
                                  Center(
                                    child: Text(
                                      'Aucune réclamation trouvée.',
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  return _reclamationCard(
                                    items[index],
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
