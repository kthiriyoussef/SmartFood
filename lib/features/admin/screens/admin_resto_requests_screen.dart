import 'package:flutter/material.dart';
import 'package:smartfood/features/admin/services/restaurant_request_service.dart';

class AdminRestoRequestsScreen extends StatefulWidget {
  const AdminRestoRequestsScreen({
    super.key,
    required this.actorId,
  });

  final int actorId;

  @override
  State<AdminRestoRequestsScreen> createState() =>
      _AdminRestoRequestsScreenState();
}

class _AdminRestoRequestsScreenState extends State<AdminRestoRequestsScreen> {
  final _service = RestaurantRequestService();

  List<Map<String, Object?>> _requests = [];
  bool _loading = true;
  int? _processingId;
  String? _error;

  static const _green = Color(0xFF21834B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final requests = await _service.listRequests(
        actorId: widget.actorId,
      );

      if (!mounted) return;

      setState(() {
        _requests = requests;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _decide(
    Map<String, Object?> request,
    bool accept,
  ) async {
    final id = request['id'] as int;
    final name = '${request['prenom']} ${request['nom']}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          accept ? 'Accepter la demande ?' : 'Refuser la demande ?',
        ),
        content: Text(
          accept
              ? '$name deviendra directeur du restaurant '
                  '${request['restaurant_nom']}.'
              : '$name conservera son compte CLIENT.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: accept ? _green : Colors.red,
            ),
            child: Text(accept ? 'Accepter' : 'Refuser'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _processingId = id);

    try {
      await _service.decide(
        actorId: widget.actorId,
        requestId: id,
        accept: accept,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Demande acceptée : accès RESTO activé.'
                : 'Demande refusée.',
          ),
          backgroundColor: accept ? _green : Colors.orange,
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACCEPTEE':
        return _green;
      case 'REFUSEE':
        return Colors.red;
      default:
        return Colors.orange.shade800;
    }
  }

  Widget _requestCard(Map<String, Object?> request) {
    final status = request['statut'] as String;
    final pending = status == 'EN_ATTENTE';
    final processing = _processingId == request['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE3F3E8),
                  child: Icon(
                    Icons.storefront,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${request['prenom']} ${request['nom']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 11,
                    ),
                  ),
                  backgroundColor: _statusColor(status).withAlpha(20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Email : ${request['email']}'),
            const SizedBox(height: 4),
            Text(
              'Restaurant : ${request['restaurant_nom']}',
            ),
            const SizedBox(height: 4),
            Text(
              'Date : ${request['date_demande']}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            if (pending) ...[
              const SizedBox(height: 14),
              if (processing)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _processingId != null
                            ? null
                            : () => _decide(request, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Accepter'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _processingId != null
                            ? null
                            : () => _decide(request, false),
                        icon: const Icon(Icons.close),
                        label: const Text('Refuser'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _requests.where((r) => r['statut'] == 'EN_ATTENTE').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes RESTO'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: const Color(0xFFE3F3E8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.pending_actions,
                            color: _green,
                          ),
                          title: const Text(
                            'Demandes en attente',
                          ),
                          trailing: Text(
                            '$pendingCount',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _green,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_requests.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Aucune demande RESTO.',
                            ),
                          ),
                        ),
                      ..._requests.map(_requestCard),
                    ],
                  ),
                ),
    );
  }
}
