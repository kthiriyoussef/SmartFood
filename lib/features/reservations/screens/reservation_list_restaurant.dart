import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/restaurant_reservation_detail_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/reservations/widgets/reservation_card.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

/// Vue restaurant : réservations reçues, filtrables par restaurant et statut.
/// Les réservations en cours passent en premier, triées par heure de retrait.
class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({
    super.key,
    this.restaurantId,
    this.initialStatus,
  });

  /// Si renseigné, la liste est limitée à ce restaurant (pas de sélecteur).
  final int? restaurantId;
  final String? initialStatus;

  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  final _service = ReservationService();
  final _restaurantService = RestaurantService();

  List<Reservation> _reservations = const [];
  List<Restaurant> _restaurants = const [];
  bool _loading = true;
  late String? _statusFilter = widget.initialStatus;
  late int? _restaurantFilter = widget.restaurantId;

  bool get _lockedToRestaurant => widget.restaurantId != null;

  @override
  void initState() {
    super.initState();
    _load();
    DataChanges.reservations.addListener(_load);
  }

  @override
  void dispose() {
    DataChanges.reservations.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final reservations = await _service.getReservations();
    final restaurants =
        await _restaurantService.getRestaurants(inclureArchives: true);
    if (!mounted) return;
    setState(() {
      _reservations = reservations;
      _restaurants = restaurants;
      _loading = false;
    });
  }

  List<Reservation> get _scoped => _restaurantFilter == null
      ? _reservations
      : _reservations
          .where((r) => r.restaurantId == _restaurantFilter)
          .toList();

  List<Reservation> get _visible {
    final list = _statusFilter == null
        ? [..._scoped]
        : _scoped.where((r) => r.status == _statusFilter).toList();
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      // En cours : le plus proche d'abord. Clôturées : la plus récente d'abord.
      return a.isActive
          ? a.pickupAt.compareTo(b.pickupAt)
          : b.pickupAt.compareTo(a.pickupAt);
    });
    return list;
  }

  int _count(String status) => _scoped.where((r) => r.status == status).length;

  Future<void> _open(Reservation reservation) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RestaurantReservationDetailScreen(reservation: reservation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final lockedName = _lockedToRestaurant
        ? _restaurants
            .where((r) => r.id == widget.restaurantId)
            .map((r) => r.nom)
            .firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          lockedName == null
              ? 'Réservations reçues'
              : 'Réservations · $lockedName',
        ),
      ),
      body: Column(
        children: [
          if (!_lockedToRestaurant && _restaurants.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<int?>(
                initialValue: _restaurantFilter,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.storefront_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Tous les restaurants'),
                  ),
                  for (final r in _restaurants)
                    DropdownMenuItem<int?>(value: r.id, child: Text(r.nom)),
                ],
                onChanged: (v) => setState(() => _restaurantFilter = v),
              ),
            ),
          SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: [
                _FilterChip(
                  label: 'Toutes (${_scoped.length})',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                for (final status in ReservationStatus.all)
                  _FilterChip(
                    label:
                        '${ReservationStatus.label(status)} (${_count(status)})',
                    selected: _statusFilter == status,
                    highlight: status == ReservationStatus.enAttente &&
                        _count(status) > 0,
                    onTap: () => setState(() => _statusFilter = status),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: visible.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Aucune réservation.')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final reservation = visible[index];
                              return ReservationCard(
                                reservation: reservation,
                                onTap: () => _open(reservation),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: highlight ? AppColors.warningBackground : Colors.white,
        labelStyle: TextStyle(
          color: selected
              ? Colors.white
              : highlight
                  ? AppColors.warning
                  : AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : highlight
                  ? AppColors.warning
                  : AppColors.border,
        ),
      ),
    );
  }
}
