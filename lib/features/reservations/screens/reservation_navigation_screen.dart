import 'package:flutter/material.dart';
import 'package:smartfood/app/theme.dart';
import 'package:smartfood/features/reservations/models/reservation.dart';
import 'package:smartfood/features/reservations/screens/reservation_details_client.dart';
import 'package:smartfood/features/reservations/screens/reservation_form_client.dart';
import 'package:smartfood/features/reservations/screens/reservation_history_client_screen.dart';
import 'package:smartfood/features/reservations/screens/reservation_list_restaurant.dart';

class ReservationNavigationScreen extends StatelessWidget {
  const ReservationNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockReservation = Reservation(
      id: 'R-204',
      clientName: 'Sonia Ben Ali',
      pickupTime: 'Aujourd’hui · 18h30',
      status: 'EN_ATTENTE',
      pinCode: '8492',
      phoneNumber: '+21622345678',
    );

    final items = [
      _NavItem(
        title: 'Créer réservation',
        subtitle: 'Formulaire client + stock + heure de retrait',
        color: AppColors.primary,
        icon: Icons.add_circle_rounded,
        screen: const ReservationFormScreen(),
      ),
      _NavItem(
        title: 'Liste réservations',
        subtitle: 'Vue globale des réservations clients',
        color: AppColors.secondary,
        icon: Icons.list_alt_rounded,
        screen: const ReservationListScreen(),
      ),
      _NavItem(
        title: 'Historique client',
        subtitle: 'Filtre par réservations actives, récupérées et annulées',
        color: const Color(0xFF0F766E),
        icon: Icons.history_rounded,
        screen: const ReservationHistoryClientScreen(),
      ),
      _NavItem(
        title: 'Détail réservation',
        subtitle: 'PIN, statut, actions de récupération',
        color: const Color(0xFF0F766E),
        icon: Icons.receipt_long_rounded,
        screen: ReservationDetailScreen(reservation: mockReservation),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('SmartFood • Réservations'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigation provisoire',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Accès rapide à tous les écrans du module réservation',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _BuildNavigationCard(
                      item: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => item.screen),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildNavigationCard extends StatelessWidget {
  const _BuildNavigationCard({required this.item, required this.onTap});

  final _NavItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.screen,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Widget screen;
}
