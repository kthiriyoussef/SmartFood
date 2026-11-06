import 'package:flutter/material.dart';

import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/auth/services/session_service.dart';
import 'package:smartfood/features/reclamation/models/reclamation.dart';
import 'package:smartfood/features/reclamation/repositories/reclamation_repository.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_details_client.dart';
import 'package:smartfood/features/reclamation/screens/reclamation_form_client.dart';
import 'package:smartfood/features/reclamation/widgets/reclamation_card.dart';

class ReclamationHistoryClientScreen extends StatefulWidget {
  const ReclamationHistoryClientScreen({super.key});

  @override
  State<ReclamationHistoryClientScreen> createState() =>
      _ReclamationHistoryClientScreenState();
}

class _ReclamationHistoryClientScreenState
    extends State<ReclamationHistoryClientScreen> {
  final _repository = ReclamationRepository();

  List<Reclamation> _reclamations = [];

  bool _loading = true;
  String? _error;

  String _statusFilter = 'TOUTES';
  String _priorityFilter = 'TOUTES';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ======================================
  // CHARGEMENT
  // ======================================

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await SessionService.instance.restoreUser();

      if (user == null || user['role'] != 'CLIENT') {
        throw StateError(
          'Session CLIENT introuvable.',
        );
      }

      final rows = await _repository.history(
        userId: user['id'] as int,
      );

      if (!mounted) return;

      setState(() {
        _reclamations = rows.map(Reclamation.fromMap).toList();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ======================================
  // PRIORITE
  // ======================================

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

  // ======================================
  // FILTRES ET TRI
  // ======================================

  List<Reclamation> get _filtered {
    final items = _reclamations.where((r) {
      bool matchesStatus;

      switch (_statusFilter) {
        case 'EN_COURS':
          matchesStatus = r.status == 'EN_ATTENTE' || r.status == 'EN_COURS';
          break;
        case 'RESOLUES':
          matchesStatus = r.status == 'RESOLUE';
          break;
        case 'REJETEES':
          matchesStatus = r.status == 'REJETEE';
          break;
        default:
          matchesStatus = true;
      }

      final matchesPriority =
          _priorityFilter == 'TOUTES' || r.priorite == _priorityFilter;

      return matchesStatus && matchesPriority;
    }).toList();

    items.sort((a, b) {
      final openA = a.isEnCours ? 1 : 0;
      final openB = b.isEnCours ? 1 : 0;

      final openComparison = openB.compareTo(openA);

      if (openComparison != 0) {
        return openComparison;
      }

      final priorityComparison = _priorityRank(b.priorite).compareTo(
        _priorityRank(a.priorite),
      );

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      // Identifiants de tickets numeriques.
      final idA = int.tryParse(
            a.id.replaceFirst('T-', ''),
          ) ??
          0;

      final idB = int.tryParse(
            b.id.replaceFirst('T-', ''),
          ) ??
          0;

      return idB.compareTo(idA);
    });

    return items;
  }

  int get _urgentCount {
    return _reclamations.where((r) {
      return r.isUrgente && r.isEnCours;
    }).length;
  }

  // ======================================
  // OUVERTURE DU FORMULAIRE
  // ======================================

  Future<void> _openForm() async {
    final id = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => const ReclamationFormScreen(),
      ),
    );

    if (!mounted) return;

    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Réclamation T-$id enregistrée.',
          ),
        ),
      );

      await _load();
    }
  }

  // ======================================
  // DETAILS
  // ======================================

  Future<void> _openDetails(
    Reclamation reclamation,
  ) async {
    try {
      final user = await SessionService.instance.restoreUser();

      if (!mounted) return;

      if (user == null || user['role'] != 'CLIENT') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée.'),
          ),
        );
        return;
      }

      final ticketId = int.tryParse(
        reclamation.id.replaceFirst('T-', ''),
      );

      if (ticketId == null) return;

      final row = await _repository.details(
        userId: user['id'] as int,
        reclamationId: ticketId,
      );

      if (!mounted) return;

      if (row == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Réclamation introuvable.',
            ),
          ),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReclamationDetailScreen(
            reclamation: Reclamation.fromMap(row),
          ),
        ),
      );

      if (!mounted) return;

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'),
        ),
      );
    }
  }

  // ======================================
  // FILTRES VISUELS
  // ======================================

  Widget _chip(
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
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
        ),
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

  // ======================================
  // INTERFACE
  // ======================================

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes réclamations'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Réclamer'),
      ),
      body: Column(
        children: [
          // COMPTEURS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_reclamations.length}',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text(
                            'Urgentes ouvertes',
                            style: TextStyle(
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_urgentCount',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // FILTRE STATUT
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
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
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              children: [
                _chip(
                  'Toutes',
                  'TOUTES',
                  isPriority: false,
                ),
                _chip(
                  'En cours',
                  'EN_COURS',
                  isPriority: false,
                ),
                _chip(
                  'Résolues',
                  'RESOLUES',
                  isPriority: false,
                ),
                _chip(
                  'Rejetées',
                  'REJETEES',
                  isPriority: false,
                ),
              ],
            ),
          ),

          // FILTRE PRIORITE
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
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
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              children: [
                _chip(
                  'Toutes',
                  'TOUTES',
                  isPriority: true,
                ),
                _chip(
                  'Urgentes',
                  'URGENTE',
                  isPriority: true,
                ),
                _chip(
                  'Élevées',
                  'ELEVEE',
                  isPriority: true,
                ),
                _chip(
                  'Moyennes',
                  'MOYENNE',
                  isPriority: true,
                ),
                _chip(
                  'Faibles',
                  'FAIBLE',
                  isPriority: true,
                ),
              ],
            ),
          ),

          // RESULTATS
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  100,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final reclamation = items[index];

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 12,
                                    ),
                                    child: ReclamationCard(
                                      reclamation: reclamation,
                                      onTap: () => _openDetails(
                                        reclamation,
                                      ),
                                    ),
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
