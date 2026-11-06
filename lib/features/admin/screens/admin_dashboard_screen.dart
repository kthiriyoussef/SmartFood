
import 'package:flutter/material.dart';
import 'package:smartfood/features/users/services/user_management_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.actorId});
  final int actorId;
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = UserManagementService();
  Map<String, int>? _stats;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final stats = await _service.statistics(actorId: widget.actorId);
      if (mounted) setState(() { _stats = stats; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SmartFood • Administration'),
      actions: [IconButton(onPressed: _load,
        icon: const Icon(Icons.refresh))]),
    body: _error != null
      ? Center(child: Text(_error!))
      : _stats == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load,
          child: GridView.count(
            padding: const EdgeInsets.all(20),
            crossAxisCount: 2, childAspectRatio: 1.4,
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            children: [
              _tile('Utilisateurs', _stats!['total']!, Icons.people),
              _tile('Actifs', _stats!['active']!, Icons.verified_user),
              _tile('Inactifs', _stats!['inactive']!, Icons.person_off),
              _tile('Directeurs RESTO', _stats!['resto']!, Icons.store),
              _tile('Clients', _stats!['client']!, Icons.person),
              _tile('Restaurants', _stats!['restaurants']!, Icons.restaurant),
            ],
          )),
  );
  Widget _tile(String label, int count, IconData icon) => Card(
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon, size: 30),
          Text('$count', style: const TextStyle(
            fontSize: 30, fontWeight: FontWeight.bold)),
          Text(label, textAlign: TextAlign.center)])));
}
