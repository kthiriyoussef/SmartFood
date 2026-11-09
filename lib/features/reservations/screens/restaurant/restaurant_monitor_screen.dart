import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartfood/app/restaurant_tabs.dart';
import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/core/utils/phone_call.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/restaurant/restaurant_reservation_detail_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/reservations/widgets/note_analysis_badges.dart';
import 'package:smartfood/features/reservations/widgets/pickup_validation_sheet.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/restaurant_detail_screen.dart';
import 'package:smartfood/features/restaurants/services/menu_service.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

/// Écran principal de l'espace restaurant : surveillance des réservations
/// en cours, organisées par étape, avec une action par carte.
class RestaurantMonitorScreen extends StatefulWidget {
  const RestaurantMonitorScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  State<RestaurantMonitorScreen> createState() =>
      _RestaurantMonitorScreenState();
}

class _RestaurantMonitorScreenState extends State<RestaurantMonitorScreen> {
  final _reservationService = ReservationService();
  final _restaurantService = RestaurantService();
  final _menuService = MenuService();

  Restaurant? _restaurant;
  List<Reservation> _reservations = const [];
  List<Menu> _menus = const [];
  bool _loading = true;
  final Set<int> _busyIds = {};

  /// Ids des réservations « En attente » déjà vues (détection des nouvelles).
  Set<int>? _knownPendingIds;

  /// Rafraîchit l'affichage (retards) toutes les 30 s.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    DataChanges.reservations.addListener(_load);
    DataChanges.catalog.addListener(_load);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    DataChanges.reservations.removeListener(_load);
    DataChanges.catalog.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final restaurant =
        await _restaurantService.getRestaurantById(widget.restaurantId);
    final reservations = await _reservationService.getReservations(
      restaurantId: widget.restaurantId,
    );
    final menus = await _menuService.getMenusByRestaurant(widget.restaurantId);
    if (!mounted) return;

    _notifyNewReservations(reservations);
    // Notes pas encore analysées par l'IA (anciennes réservations…).
    _reservationService.analyzeMissingNotes(reservations);
    setState(() {
      _restaurant = restaurant;
      _reservations = reservations;
      _menus = menus;
      _loading = false;
    });
  }

  void _notifyNewReservations(List<Reservation> reservations) {
    final pending = reservations
        .where((r) => r.status == ReservationStatus.enAttente)
        .toList();
    final ids = pending.map((r) => r.id!).toSet();
    final known = _knownPendingIds;
    _knownPendingIds = ids;
    if (known == null) return; // premier chargement : pas d'alerte
    final fresh = pending.where((r) => !known.contains(r.id)).toList();
    if (fresh.isEmpty) return;
    HapticFeedback.heavyImpact();
    final r = fresh.first;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.secondary,
          duration: const Duration(seconds: 5),
          content: Text(
            fresh.length == 1
                ? '🔔 Nouvelle réservation : ${r.dishNames} pour ${r.pickupTime}'
                : '🔔 ${fresh.length} nouvelles réservations',
          ),
          action: SnackBarAction(
            label: 'Confirmer',
            textColor: Colors.white,
            onPressed: () => _advance(r),
          ),
        ),
      );
  }

  Future<void> _advance(Reservation reservation) async {
    final next = ReservationService.nextStatus(reservation.status);
    if (next == null) return;
    setState(() => _busyIds.add(reservation.id!));
    try {
      await _reservationService.advanceStatus(reservation, next);
    } on ReservationException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busyIds.remove(reservation.id));
    }
  }

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? AppColors.error : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _open(Reservation reservation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RestaurantReservationDetailScreen(reservation: reservation),
      ),
    );
  }

  void _openRestaurant() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RestaurantDetailScreen(restaurantId: widget.restaurantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;

    // Les réservations avec allergie passent en tête, puis par heure.
    List<Reservation> byStatus(Set<String> statuses) =>
        _reservations.where((r) => statuses.contains(r.status)).toList()
          ..sort((a, b) {
            if (a.hasAllergy != b.hasAllergy) return a.hasAllergy ? -1 : 1;
            return a.pickupAt.compareTo(b.pickupAt);
          });
    final allergies = _reservations
        .where((r) => r.isActive && r.hasAllergy)
        .length;

    final pending = byStatus({ReservationStatus.enAttente});
    final kitchen =
        byStatus({ReservationStatus.confirmee, ReservationStatus.preparation});
    final ready = byStatus({ReservationStatus.prete});
    final late = [...pending, ...kitchen, ...ready]
        .where((r) => r.pickupAt.isBefore(now))
        .length;
    final pickedToday = _reservations.where(
      (r) => r.status == ReservationStatus.recuperee && isToday(r.pickupAt),
    );
    final revenue = pickedToday.fold<double>(0, (s, r) => s + r.total);
    final soldOut =
        _menus.where((m) => m.quantite == 0 || !m.disponible).length;
    final lowStock = _menus
        .where((m) =>
            m.disponible &&
            m.quantite > 0 &&
            m.quantite <= MenuService.seuilStockBas)
        .length;
    final closed = _restaurant?.statut == RestaurantStatus.archive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Suivi des réservations'),
            if (_restaurant != null)
              Text(
                _restaurant!.nom,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mon restaurant',
            onPressed: _openRestaurant,
            icon: const Icon(Icons.storefront_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            PickupValidationSheet.show(context, widget.restaurantId),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Retrait client'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (closed)
                    _AlertBar(
                      icon: Icons.storefront_outlined,
                      color: AppColors.error,
                      text: 'Restaurant fermé : invisible pour les clients.',
                      onTap: _openRestaurant,
                    ),
                  Row(
                    children: [
                      _Counter(
                        value: pending.length,
                        label: 'À confirmer',
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      _Counter(
                        value: kitchen.length,
                        label: 'En cuisine',
                        color: const Color(0xFF0F766E),
                      ),
                      const SizedBox(width: 8),
                      _Counter(
                        value: ready.length,
                        label: 'Prêtes',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Aujourd’hui : ${pickedToday.length} retrait(s) · '
                    '${revenue.toStringAsFixed(revenue % 1 == 0 ? 0 : 2)} DT encaissés',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (allergies > 0)
                    _AlertBar(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.error,
                      text: '$allergies réservation(s) avec allergie signalée',
                    ),
                  if (late > 0)
                    _AlertBar(
                      icon: Icons.timer_off_outlined,
                      color: AppColors.error,
                      text:
                          '$late réservation(s) en retard sur l’heure de retrait',
                    ),
                  if (soldOut > 0 || lowStock > 0)
                    _AlertBar(
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.warning,
                      text: [
                        if (soldOut > 0) '$soldOut plat(s) indisponible(s)',
                        if (lowStock > 0) '$lowStock en stock bas',
                      ].join(' · '),
                      onTap: () => RoleShell.of(context)
                          ?.selectTab(RestaurantTabs.dishes),
                    ),
                  _Section(
                    title: 'À confirmer',
                    color: AppColors.secondary,
                    empty: 'Aucune nouvelle réservation.',
                    reservations: pending,
                    busyIds: _busyIds,
                    onAdvance: _advance,
                    onOpen: _open,
                  ),
                  _Section(
                    title: 'En cuisine',
                    color: const Color(0xFF0F766E),
                    empty: 'Rien en préparation.',
                    reservations: kitchen,
                    busyIds: _busyIds,
                    onAdvance: _advance,
                    onOpen: _open,
                  ),
                  _Section(
                    title: 'Prêtes au retrait',
                    color: AppColors.primary,
                    empty: 'Aucune commande prête.',
                    reservations: ready,
                    busyIds: _busyIds,
                    onAdvance: (_) => PickupValidationSheet.show(
                      context,
                      widget.restaurantId,
                    ),
                    onOpen: _open,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withAlpha(value > 0 ? 30 : 12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertBar extends StatelessWidget {
  const _AlertBar({
    required this.icon,
    required this.color,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.color,
    required this.empty,
    required this.reservations,
    required this.busyIds,
    required this.onAdvance,
    required this.onOpen,
  });

  final String title;
  final Color color;
  final String empty;
  final List<Reservation> reservations;
  final Set<int> busyIds;
  final ValueChanged<Reservation> onAdvance;
  final ValueChanged<Reservation> onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '$title (${reservations.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (reservations.isEmpty)
            Text(empty, style: const TextStyle(color: AppColors.muted))
          else
            for (final r in reservations)
              _ReservationTile(
                reservation: r,
                busy: busyIds.contains(r.id),
                onAdvance: () => onAdvance(r),
                onTap: () => onOpen(r),
              ),
        ],
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({
    required this.reservation,
    required this.busy,
    required this.onAdvance,
    required this.onTap,
  });

  final Reservation reservation;
  final bool busy;
  final VoidCallback onAdvance;
  final VoidCallback onTap;

  /// Libellé du bouton d'action principal selon l'étape.
  String get _actionLabel => switch (reservation.status) {
        ReservationStatus.enAttente => 'Confirmer',
        ReservationStatus.confirmee => 'En préparation',
        ReservationStatus.preparation => 'Prête',
        _ => 'Retrait',
      };

  IconData get _actionIcon => switch (reservation.status) {
        ReservationStatus.enAttente => Icons.check_rounded,
        ReservationStatus.confirmee => Icons.soup_kitchen_rounded,
        ReservationStatus.preparation => Icons.shopping_bag_rounded,
        _ => Icons.qr_code_scanner_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final late = reservation.pickupAt.isBefore(now);
    final minutes = reservation.pickupAt.difference(now).inMinutes;
    final timing = late
        ? 'en retard de ${-minutes} min'
        : minutes < 60
            ? 'dans $minutes min'
            : reservation.pickupTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: late || reservation.hasAllergy
              ? AppColors.error
              : AppColors.border,
          width: late || reservation.hasAllergy ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          late ? Icons.timer_off_outlined : Icons.schedule,
                          size: 16,
                          color: late ? AppColors.error : AppColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${reservation.pickupAt.hour.toString().padLeft(2, '0')}:${reservation.pickupAt.minute.toString().padLeft(2, '0')} · $timing',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: late ? AppColors.error : AppColors.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.dishNames,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${reservation.clientName} · ${reservation.reference}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                        if (reservation.note != null) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Note : ${reservation.note}',
                            child: const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (reservation.note != null) ...[
                      const SizedBox(height: 6),
                      NoteAnalysisBadges(
                        reservation: reservation,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Avant de confirmer, le restaurant peut appeler le client.
              if (reservation.status == ReservationStatus.enAttente) ...[
                IconButton.outlined(
                  tooltip: 'Appeler ${reservation.clientName}',
                  onPressed: () => callPhone(context, reservation.phoneNumber),
                  icon:
                      const Icon(Icons.phone_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 4),
              ],
              busy
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: onAdvance,
                      icon: Icon(_actionIcon, size: 18),
                      label: Text(_actionLabel),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
