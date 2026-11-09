import 'package:flutter/material.dart';
import 'package:smartfood/features/users/services/user_management_service.dart';
import 'package:smartfood/features/admin/screens/admin_restaurant_access_screen.dart';
import 'package:smartfood/features/admin/services/restaurant_access_service.dart';
import 'package:smartfood/features/admin/services/restaurant_request_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.actorId,
  });

  final int actorId;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = UserManagementService();
  final _requestService = RestaurantAccessService();
  final _legacyRequestService = RestaurantRequestService();

  Map<String, int>? _stats;
  int _pendingRequests = 0;
  int _pendingLegacyRequests = 0;
  String? _error;
  bool _loading = true;

  static const Color primaryColor = Color(0xFF21834B);

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
      final stats = await _service.statistics(
        actorId: widget.actorId,
      );

      final pending = await _requestService.pendingCount(
        actorId: widget.actorId,
      );
      final pendingLegacy = await _legacyRequestService.pendingCount(
        actorId: widget.actorId,
      );

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _pendingRequests = pending;
        _pendingLegacyRequests = pendingLegacy;
        _error = null;
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

  Widget _tile(
    String label,
    int count,
    IconData icon, {
    Color color = primaryColor,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 30,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartFood • Administration'),
        actions: [
          IconButton(
            tooltip: 'Accorder un accès RESTO',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminRestaurantAccessScreen(
                    actorId: widget.actorId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth > 650 ? 3 : 2;

                      return GridView.count(
                        padding: const EdgeInsets.all(20),
                        crossAxisCount: columns,
                        childAspectRatio: 1.4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        children: [
                          _tile(
                            'Utilisateurs',
                            _stats?['total'] ?? 0,
                            Icons.people,
                          ),
                          _tile(
                            'Actifs',
                            _stats?['active'] ?? 0,
                            Icons.verified_user,
                          ),
                          _tile(
                            'Inactifs',
                            _stats?['inactive'] ?? 0,
                            Icons.person_off,
                            color: Colors.grey,
                          ),
                          _tile(
                            'Directeurs RESTO',
                            _stats?['resto'] ?? 0,
                            Icons.store,
                          ),
                          _tile(
                            'Clients',
                            _stats?['client'] ?? 0,
                            Icons.person,
                          ),
                          _tile(
                            'Restaurants',
                            _stats?['restaurants'] ?? 0,
                            Icons.restaurant,
                          ),
                          _tile(
                            'Demandes d’accès RESTO en attente',
                            _pendingRequests,
                            Icons.pending_actions,
                            color: Colors.orange,
                          ),
                          _tile(
                            'Demandes sur restaurants existants',
                            _pendingLegacyRequests,
                            Icons.store_mall_directory_outlined,
                            color: Colors.deepOrange,
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}
