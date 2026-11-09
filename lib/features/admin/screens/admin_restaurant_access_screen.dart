import 'package:flutter/material.dart';
import 'package:smartfood/features/admin/services/restaurant_access_service.dart';

class AdminRestaurantAccessScreen extends StatefulWidget {
  const AdminRestaurantAccessScreen({
    super.key,
    required this.actorId,
  });

  final int actorId;

  @override
  State<AdminRestaurantAccessScreen> createState() =>
      _AdminRestaurantAccessScreenState();
}

class _AdminRestaurantAccessScreenState
    extends State<AdminRestaurantAccessScreen> {
  final _service = RestaurantAccessService();

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
      final requests = await _service.listRequests(actorId: widget.actorId);
      if (!mounted) return;
      setState(() => _requests = requests);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(
    Map<String, Object?> request,
    bool approve,
  ) async {
    final id = request['id'] as int;
    final name = request['user_name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          approve ? 'Approve restaurant access?' : 'Reject restaurant access?',
        ),
        content: Text(
          approve
              ? '$name will receive the restaurant role and can create their '
                  'restaurant after their next login. No restaurant is '
                  'created now.'
              : '$name will keep the customer role.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? _green : Colors.red,
            ),
            child: Text(approve ? 'Approve' : 'Reject'),
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
        approve: approve,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Restaurant access approved.' : 'Request rejected.',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return _green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange.shade800;
    }
  }

  String _date(Object? value) {
    final date = DateTime.tryParse(value as String? ?? '');
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _requestCard(Map<String, Object?> request) {
    final status = request['status'] as String;
    final pending = status == 'pending';
    final processing = _processingId == request['id'];
    final reviewer = [
      request['reviewer_prenom'],
      request['reviewer_nom'],
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ');

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
                  child: Icon(Icons.storefront, color: _green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    request['user_name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: _statusColor(status).withAlpha(20),
                  labelStyle: TextStyle(color: _statusColor(status)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Email: ${request['user_email']}'),
            Text('Requested role: ${request['requested_role']}'),
            Text('Submitted: ${_date(request['submitted_at'])}'),
            if (!pending) ...[
              Text('Reviewed: ${_date(request['reviewed_at'])}'),
              if (reviewer.isNotEmpty) Text('Reviewed by: $reviewer'),
            ],
            if (pending) ...[
              const SizedBox(height: 14),
              if (processing)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _processingId == null
                            ? () => _decide(request, false)
                            : null,
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _processingId == null
                            ? () => _decide(request, true)
                            : null,
                        child: const Text('Approve'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Access Requests'),
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _requests.isEmpty
                  ? const Center(child: Text('No restaurant access requests.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _requests.map(_requestCard).toList(),
                      ),
                    ),
    );
  }
}
