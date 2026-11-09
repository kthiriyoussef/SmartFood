import 'package:flutter/material.dart';
import 'package:smartfood/app/restaurant_tabs.dart';
import 'package:smartfood/app/role_shell.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/core/database/data_changes.dart';
import 'package:smartfood/core/utils/phone_call.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/restaurant/restaurant_reservation_detail_screen.dart';
import 'package:smartfood/features/reservations/services/reservation_service.dart';
import 'package:smartfood/features/restaurants/models/menu.dart';
import 'package:smartfood/features/restaurants/models/restaurant.dart';
import 'package:smartfood/features/restaurants/screens/restaurant/restaurant_detail_screen.dart';
import 'package:smartfood/features/restaurants/services/menu_service.dart';
import 'package:smartfood/features/restaurants/services/restaurant_service.dart';

/// Tableau de bord informationnel du restaurant : chiffres du jour,
/// réservations à confirmer (avec appel du client), activité de la semaine,
/// plats les plus demandés et état de la carte.
class RestaurantDashboardScreen extends StatefulWidget {
  const RestaurantDashboardScreen({super.key, required this.restaurantId});

  final int restaurantId;

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  final _reservationService = ReservationService();
  final _restaurantService = RestaurantService();
  final _menuService = MenuService();

  Restaurant? _restaurant;
  List<Reservation> _reservations = const [];
  List<Menu> _menus = const [];
  bool _loading = true;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
    DataChanges.reservations.addListener(_load);
    DataChanges.catalog.addListener(_load);
  }

  @override
  void dispose() {
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
    setState(() {
      _restaurant = restaurant;
      _reservations = reservations;
      _menus = menus;
      _loading = false;
    });
  }

  Future<void> _confirm(Reservation reservation) async {
    setState(() => _busyIds.add(reservation.id!));
    try {
      await _reservationService.advanceStatus(
        reservation,
        ReservationStatus.confirmee,
      );
      _snack('${reservation.reference} confirmée');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

    final notCancelled =
        _reservations.where((r) => r.status != ReservationStatus.annulee);
    final todayReservations =
        notCancelled.where((r) => dayOf(r.pickupAt) == today).toList();
    final pickedToday = todayReservations
        .where((r) => r.status == ReservationStatus.recuperee)
        .toList();
    final revenueToday = pickedToday.fold<double>(0, (s, r) => s + r.total);
    final picked =
        _reservations.where((r) => r.status == ReservationStatus.recuperee);
    final averageBasket = picked.isEmpty
        ? 0.0
        : picked.fold<double>(0, (s, r) => s + r.total) / picked.length;

    // Taux d'annulation sur les 7 derniers jours (date de retrait).
    final weekStart = today.subtract(const Duration(days: 6));
    final week =
        _reservations.where((r) => !dayOf(r.pickupAt).isBefore(weekStart));
    final cancelledWeek =
        week.where((r) => r.status == ReservationStatus.annulee).length;
    final cancelRate =
        week.isEmpty ? 0 : (cancelledWeek * 100 / week.length).round();

    final pending = _reservations
        .where((r) => r.status == ReservationStatus.enAttente)
        .toList()
      ..sort((a, b) => a.pickupAt.compareTo(b.pickupAt));

    // Activité : réservations (non annulées) par jour de retrait, 7 jours.
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))
    ];
    final perDay = [
      for (final d in days)
        notCancelled.where((r) => dayOf(r.pickupAt) == d).length,
    ];

    // Plats les plus réservés (portions, hors annulations).
    final portions = <String, int>{};
    for (final r in notCancelled) {
      portions.update(r.dishName, (v) => v + r.quantity,
          ifAbsent: () => r.quantity);
    }
    final topDishes = portions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final onSale = _menus.where((m) => m.disponible && m.quantite > 0).length;
    final low = _menus
        .where((m) =>
            m.disponible &&
            m.quantite > 0 &&
            m.quantite <= MenuService.seuilStockBas)
        .length;
    final out = _menus.where((m) => !m.disponible || m.quantite == 0).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            tooltip: 'Mon restaurant',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    RestaurantDetailScreen(restaurantId: widget.restaurantId),
              ),
            ),
            icon: const Icon(Icons.storefront_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Header(
              restaurant: _restaurant,
              todayCount: todayReservations.length,
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _Kpi(
                  label: 'Encaissé aujourd’hui',
                  value: _money(revenueToday),
                  detail: '${pickedToday.length} retrait(s)',
                  icon: Icons.payments_outlined,
                ),
                _Kpi(
                  label: 'Réservations du jour',
                  value: '${todayReservations.length}',
                  detail: '${pending.length} à confirmer',
                  icon: Icons.event_note_outlined,
                ),
                _Kpi(
                  label: 'Panier moyen',
                  value: _money(averageBasket),
                  detail: 'sur ${picked.length} retrait(s)',
                  icon: Icons.shopping_basket_outlined,
                ),
                _Kpi(
                  label: 'Annulations (7 j)',
                  value: '$cancelRate %',
                  detail: '$cancelledWeek sur ${week.length}',
                  icon: Icons.cancel_outlined,
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ---------------------------------------------- À confirmer
            _SectionHeader(
              title: 'À confirmer',
              count: pending.length,
              action: pending.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => RoleShell.of(context)
                          ?.selectTab(RestaurantTabs.monitor),
                      child: const Text('Ouvrir le suivi'),
                    ),
            ),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              const _EmptyCard(
                icon: Icons.check_circle_outline_rounded,
                text: 'Toutes les réservations sont confirmées.',
              )
            else
              for (final r in pending)
                _PendingCard(
                  reservation: r,
                  busy: _busyIds.contains(r.id),
                  onCall: () => callPhone(context, r.phoneNumber),
                  onConfirm: () => _confirm(r),
                  onTap: () => _open(r),
                ),
            const SizedBox(height: 22),

            // --------------------------------------------- Activité
            const _SectionHeader(title: 'Activité · 7 derniers jours'),
            const SizedBox(height: 4),
            Text(
              'Réservations par jour de retrait (hors annulations). '
              'Touchez une barre pour le détail.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            _WeekChart(days: days, values: perDay),
            const SizedBox(height: 22),

            // ------------------------------------------- Top plats
            const _SectionHeader(title: 'Plats les plus réservés'),
            const SizedBox(height: 8),
            if (topDishes.isEmpty)
              const _EmptyCard(
                icon: Icons.restaurant_menu_rounded,
                text: 'Pas encore de réservation.',
              )
            else
              _TopDishes(entries: topDishes.take(5).toList()),
            const SizedBox(height: 22),

            // ------------------------------------------- Carte
            _SectionHeader(
              title: 'État de la carte',
              action: TextButton(
                onPressed: () =>
                    RoleShell.of(context)?.selectTab(RestaurantTabs.dishes),
                child: const Text('Gérer les plats'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MenuState(
                  icon: Icons.check_circle_rounded,
                  label: 'En vente',
                  value: onSale,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                _MenuState(
                  icon: Icons.warning_amber_rounded,
                  label: 'Stock bas',
                  value: low,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _MenuState(
                  icon: Icons.block_rounded,
                  label: 'Indisponibles',
                  value: out,
                  color: AppColors.error,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double value) =>
      '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)} DT';
}

// ================================================================ Widgets

class _Header extends StatelessWidget {
  const _Header({required this.restaurant, required this.todayCount});

  final Restaurant? restaurant;
  final int todayCount;

  static const _weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final open = restaurant?.statut == RestaurantStatus.actif;
    final white = Colors.white.withAlpha(220);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C4E25), AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonjour 👋',
                  style: TextStyle(color: white),
                ),
                const SizedBox(height: 2),
                Text(
                  restaurant?.nom ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]} · '
                  '$todayCount réservation(s) aujourd’hui',
                  style: TextStyle(color: white),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  open ? Icons.circle : Icons.circle_outlined,
                  size: 10,
                  color: open ? AppColors.primary : AppColors.error,
                ),
                const SizedBox(width: 6),
                Text(
                  open ? 'Ouvert' : 'Fermé',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
            ],
          ),
          FittedBox(
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count, this.action});

  final String title;
  final int? count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (count != null && count! > 0) ...[
          const SizedBox(width: 8),
          Badge(
            backgroundColor: AppColors.secondary,
            label: Text('$count'),
          ),
        ],
        const Spacer(),
        if (action != null) action!,
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

/// Réservation en attente : appeler le client, puis confirmer.
class _PendingCard extends StatelessWidget {
  const _PendingCard({
    required this.reservation,
    required this.busy,
    required this.onCall,
    required this.onConfirm,
    required this.onTap,
  });

  final Reservation reservation;
  final bool busy;
  final VoidCallback onCall;
  final VoidCallback onConfirm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final late = reservation.pickupAt.isBefore(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: late ? AppColors.error : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.dishNames,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${reservation.total.toStringAsFixed(2)} DT',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    late ? Icons.timer_off_outlined : Icons.schedule_rounded,
                    size: 15,
                    color: late ? AppColors.error : AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    late
                        ? 'Retrait dépassé · ${reservation.pickupTime}'
                        : 'Retrait ${reservation.pickupTime}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: late ? AppColors.error : AppColors.muted,
                      fontWeight: late ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${reservation.clientName} · ${reservation.phoneNumber}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              if (reservation.note != null) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('📝 ${reservation.note}'),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_rounded, size: 18),
                      label: const Text('Appeler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onConfirm,
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Confirmer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barres verticales, une seule série (une seule couleur, pas de légende).
/// Valeurs affichées seulement pour aujourd'hui et le maximum ; le détail
/// de chaque jour apparaît au toucher (tooltip).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.days, required this.values});

  final List<DateTime> days;
  final List<int> values;

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const double _plotHeight = 120;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = values.fold<int>(0, (a, b) => a > b ? a : b);
    final maxIndex = values.indexOf(maxValue);
    final total = values.fold<int>(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$total réservation(s) sur la semaine',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _plotHeight + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          '${days[i].day.toString().padLeft(2, '0')}/${days[i].month.toString().padLeft(2, '0')} : '
                          '${values[i]} réservation(s)',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Étiquettes sélectives : aujourd'hui + maximum.
                          if (values[i] > 0 &&
                              (i == days.length - 1 || i == maxIndex))
                            Text(
                              '${values[i]}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            width: 18,
                            height: maxValue == 0
                                ? 2
                                : (values[i] / maxValue * _plotHeight)
                                    .clamp(2, _plotHeight),
                            decoration: BoxDecoration(
                              color: values[i] == 0
                                  ? AppColors.border
                                  : AppColors.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Text(
                    i == days.length - 1
                        ? 'Auj.'
                        : _letters[days[i].weekday - 1],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: i == days.length - 1
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barres horizontales (une seule série) : portions réservées par plat.
class _TopDishes extends StatelessWidget {
  const _TopDishes({required this.entries});

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = entries.first.value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      e.key,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 12,
                          width: (e.value / max * constraints.maxWidth)
                              .clamp(4, constraints.maxWidth),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${e.value}',
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'portions réservées (hors annulations)',
              style:
                  theme.textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuState extends StatelessWidget {
  const _MenuState({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
